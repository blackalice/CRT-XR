#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <windows.h>
#include <setupapi.h>
extern "C" {
#include <hidsdi.h>
}
#include <cstdint>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <mutex>
#include <string>
#include <vector>

// The SDK ABI is declared here so the build does not require vendor headers.
// Pose callback: [roll,pitch,yaw,qw,qx,qy,qz], NWU coordinates.
using Handle = void*;
using Callback = void(*)(float*, uint64_t);
std::mutex pose_mutex;
float quaternion[4] = {0,0,0,1};
ULONGLONG received = 0;
void pose_callback(float* data, uint64_t) {
    if (!data) return;
    // Match the vendor Gen1/Gen2 demo: positive pitch is down,
    // positive yaw is left, and roll rotates the up vector toward right.
    // Godot camera rotation is Y(yaw) * X(pitch) * Z(roll).
    constexpr double half_degree = 3.14159265358979323846 / 360.0;
    const double pitch = -data[1]*half_degree;
    const double yaw = data[2]*half_degree;
    const double roll = -data[0]*half_degree;
    const double cx=cos(pitch), sx=sin(pitch), cy=cos(yaw), sy=sin(yaw), cz=cos(roll), sz=sin(roll);
    float q[4] = {float(cy*sx*cz+sy*cx*sz), float(sy*cx*cz-cy*sx*sz),
                  float(cy*cx*sz-sy*sx*cz), float(cy*cx*cz+sy*sx*sz)};
    double norm = 0;
    for (float v:q) { if (!std::isfinite(v)) return; norm += v*v; }
    if (norm < .98 || norm > 1.02) return;
    std::lock_guard<std::mutex> lock(pose_mutex);
    for(int i=0;i<4;++i) quaternion[i] = float(q[i]/std::sqrt(norm));
    received = GetTickCount64();
}
int find_product(int (*valid)(int)) {
    GUID guid; HidD_GetHidGuid(&guid);
    HDEVINFO info = SetupDiGetClassDevsW(&guid,nullptr,nullptr,DIGCF_PRESENT|DIGCF_DEVICEINTERFACE);
    if(info == INVALID_HANDLE_VALUE) return -1;
    int product = -1;
    for(DWORD i=0;;++i) {
        SP_DEVICE_INTERFACE_DATA device{}; device.cbSize=sizeof(device);
        if(!SetupDiEnumDeviceInterfaces(info,nullptr,&guid,i,&device)) break;
        DWORD size=0;
        SetupDiGetDeviceInterfaceDetailW(info,&device,nullptr,0,&size,nullptr);
        if(!size) continue;
        std::vector<unsigned char> storage(size);
        auto detail=reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W*>(storage.data());
        detail->cbSize=sizeof(*detail);
        if(!SetupDiGetDeviceInterfaceDetailW(info,&device,detail,size,nullptr,nullptr)) continue;
        HANDLE hid=CreateFileW(detail->DevicePath,0,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_EXISTING,0,nullptr);
        if(hid==INVALID_HANDLE_VALUE) continue;
        HIDD_ATTRIBUTES attrs{}; attrs.Size=sizeof(attrs);
        if(HidD_GetAttributes(hid,&attrs) && attrs.VendorID==0x35ca && valid(attrs.ProductID)) product=attrs.ProductID;
        CloseHandle(hid);
        if(product>=0) break;
    }
    SetupDiDestroyDeviceInfoList(info);
    return product;
}
int wmain(int argc,wchar_t** argv) {
    if(argc!=4) return 2; // UDP port, parent PID, SDK DLL absolute path
    const int port=_wtoi(argv[1]);
    if(port<1 || port>65535) return 2;
    HANDLE parent=OpenProcess(SYNCHRONIZE,FALSE,DWORD(_wtoi(argv[2])));
    if(!parent) return 3;
    WSADATA ws{}; if(WSAStartup(MAKEWORD(2,2),&ws)) return 4;
    SOCKET sock=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP);
    sockaddr_in address{}; address.sin_family=AF_INET; address.sin_port=htons(port); address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    auto send_status=[&](const char* status) { char msg[400]; snprintf(msg,sizeof(msg),"{\"v\":1,\"valid\":false,\"status\":\"%s\"}",status); sendto(sock,msg,int(strlen(msg)),0,(sockaddr*)&address,sizeof(address)); };
    SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32|LOAD_LIBRARY_SEARCH_USER_DIRS);
    HMODULE dll=LoadLibraryExW(argv[3],nullptr,LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR|LOAD_LIBRARY_SEARCH_SYSTEM32);
    if(!dll) { send_status("VITURE SDK could not load; check SDK and Visual C++ runtime"); Sleep(500); return 5; }
#define LOAD(name,type) auto name=reinterpret_cast<type>(GetProcAddress(dll,"xr_device_provider_" #name)); if(!name) {send_status("VITURE SDK missing required API"); return 6;}
    using Create=Handle(*)(int); using Init=int(*)(Handle,const char*,const char*); using Simple=int(*)(Handle); using Destroy=void(*)(Handle); using Valid=int(*)(int); using Register=int(*)(Handle,Callback); using Open=int(*)(Handle,uint8_t,uint8_t); using Close=int(*)(Handle,uint8_t); using Frequency=int(*)(int,int,int);
    LOAD(create,Create) LOAD(initialize,Init) LOAD(start,Simple) LOAD(stop,Simple) LOAD(shutdown,Simple) LOAD(destroy,Destroy) LOAD(is_product_id_valid,Valid) LOAD(register_imu_pose_callback,Register) LOAD(open_imu,Open) LOAD(close_imu,Close) LOAD(is_product_support_imu_frequency,Frequency)
    uint64_t sequence=0;
    while(WaitForSingleObject(parent,0)==WAIT_TIMEOUT) {
        int product=find_product(is_product_id_valid);
        if(product<0) {send_status("Connect VITURE glasses by USB"); Sleep(1000); continue;}
        Handle device=create(product);
        bool initialized=false,started=false,opened=false;
        int result=device?register_imu_pose_callback(device,pose_callback):-1;
        if(!result) {result=initialize(device,nullptr,nullptr); initialized=!result;}
        if(!result) {result=start(device); started=!result;}
        if(!result) { int frequency=4; while(frequency>0 && !is_product_support_imu_frequency(product,1,frequency)) --frequency; result=open_imu(device,1,uint8_t(frequency)); opened=!result; }
        if(result) { char status[180]; snprintf(status,sizeof(status),"VITURE tracking error %d; close SpaceWalker if using glasses",result); send_status(status); }
        if(opened) {
            ULONGLONG began=GetTickCount64();
            {std::lock_guard<std::mutex> lock(pose_mutex); received=0;}
            while(WaitForSingleObject(parent,0)==WAIT_TIMEOUT) {
                float q[4]; ULONGLONG stamp;
                {std::lock_guard<std::mutex> lock(pose_mutex); stamp=received; for(int i=0;i<4;++i) q[i]=quaternion[i];}
                ULONGLONG now=GetTickCount64();
                if(stamp && now-stamp<300) {
                    char msg[400]; snprintf(msg,sizeof(msg),"{\"v\":1,\"valid\":true,\"sequence\":%llu,\"driver_ms\":%llu,\"q\":[%.9g,%.9g,%.9g,%.9g]}",(unsigned long long)++sequence,(unsigned long long)stamp,q[0],q[1],q[2],q[3]);
                    sendto(sock,msg,int(strlen(msg)),0,(sockaddr*)&address,sizeof(address));
                } else if(now-began>3000) {send_status("VITURE pose stream stopped; reconnecting"); break;}
                Sleep(4);
            }
        }
        if(opened) close_imu(device,1);
        if(started) stop(device);
        if(initialized) shutdown(device);
        if(device) destroy(device);
        Sleep(1000);
    }
    FreeLibrary(dll); closesocket(sock); WSACleanup(); CloseHandle(parent); return 0;
}
