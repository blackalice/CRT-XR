"""Add per-monitor DPI awareness to an exported Windows EXE with a separate PCK."""
from pathlib import Path
import ctypes, sys, xml.etree.ElementTree as ET
from ctypes import wintypes as w
out=Path(sys.argv[1]).resolve()
# Windows resource updates may relocate overlays. Refuse embedded Godot packs.
with out.open('rb') as stream:
    stream.seek(-4,2)
    if stream.read(4)==b'GDPC': raise RuntimeError('Use a separate PCK before editing Windows resources')
k=ctypes.WinDLL('kernel32',use_last_error=True)
k.LoadLibraryExW.argtypes=[w.LPCWSTR,w.HANDLE,w.DWORD]; k.LoadLibraryExW.restype=w.HMODULE
k.FindResourceW.argtypes=[w.HMODULE,w.LPCWSTR,w.LPCWSTR];k.FindResourceW.restype=w.HRSRC
k.SizeofResource.argtypes=[w.HMODULE,w.HRSRC];k.SizeofResource.restype=w.DWORD
k.LoadResource.argtypes=[w.HMODULE,w.HRSRC];k.LoadResource.restype=w.HGLOBAL
k.LockResource.argtypes=[w.HGLOBAL];k.LockResource.restype=w.LPVOID
k.FreeLibrary.argtypes=[w.HMODULE]
ident=ctypes.cast(ctypes.c_void_p(1),w.LPCWSTR);kind=ctypes.cast(ctypes.c_void_p(24),w.LPCWSTR)
module=k.LoadLibraryExW(str(out),None,2)
if not module: raise ctypes.WinError(ctypes.get_last_error())
try:
    resource=k.FindResourceW(module,ident,kind)
    if not resource: raise RuntimeError('Template manifest missing')
    payload=ctypes.string_at(k.LockResource(k.LoadResource(module,resource)),k.SizeofResource(module,resource))
finally: k.FreeLibrary(module)
root=ET.fromstring(payload.rstrip(b'\x00'))
ns='urn:schemas-microsoft-com:asm.v3'
application=root.find('{'+ns+'}application')
if application is None: application=ET.SubElement(root,'{'+ns+'}application')
settings=application.find('{'+ns+'}windowsSettings')
if settings is None: settings=ET.SubElement(application,'{'+ns+'}windowsSettings')
for namespace,name,value in [('http://schemas.microsoft.com/SMI/2005/WindowsSettings','dpiAware','true/pm'),('http://schemas.microsoft.com/SMI/2016/WindowsSettings','dpiAwareness','PerMonitorV2,PerMonitor')]:
    tag='{'+namespace+'}'+name
    element=settings.find(tag)
    if element is None: element=ET.SubElement(settings,tag)
    element.text=value
payload=ET.tostring(root,encoding='utf-8',xml_declaration=True)
k.BeginUpdateResourceW.argtypes=[w.LPCWSTR,w.BOOL];k.BeginUpdateResourceW.restype=w.HANDLE
k.UpdateResourceW.argtypes=[w.HANDLE,w.LPCWSTR,w.LPCWSTR,w.WORD,w.LPVOID,w.DWORD];k.UpdateResourceW.restype=w.BOOL
k.EndUpdateResourceW.argtypes=[w.HANDLE,w.BOOL];k.EndUpdateResourceW.restype=w.BOOL
update=k.BeginUpdateResourceW(str(out),False)
if not update: raise ctypes.WinError(ctypes.get_last_error())
buffer=ctypes.create_string_buffer(payload)
if not k.UpdateResourceW(update,kind,ident,1033,buffer,len(payload)):
    error=ctypes.get_last_error();k.EndUpdateResourceW(update,True);raise ctypes.WinError(error)
if not k.EndUpdateResourceW(update,False): raise ctypes.WinError(ctypes.get_last_error())
print(out)
