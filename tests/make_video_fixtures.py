"""Make ignored video fixtures for the native video decoder test.
Usage: python tests/make_video_fixtures.py [ffmpeg] [output-folder]
Needs an FFmpeg build with libx264, libx265, an AV1 encoder and libopus (any
"full" build). Every clip is 4 seconds of a white field with green bands on the
outer 4% of each side, so bars and side crops can be measured, plus a tone:
440 Hz unless noted, so pitch and timing survive resampling and seeking.
"""
from pathlib import Path
import os, subprocess, sys
ffmpeg = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("FFMPEG", "ffmpeg")
root = Path(sys.argv[2] if len(sys.argv) > 2 else "build/video-fixtures")
root.mkdir(parents=True, exist_ok=True)
def picture(size, rate, sar="1"):
    bands = "drawbox=x=0:y=0:w=iw*0.04:h=ih:color=0x00a000:t=fill,drawbox=x=iw*0.96:y=0:w=iw*0.04:h=ih:color=0x00a000:t=fill"
    return ["-f", "lavfi", "-i", f"color=c=white:s={size}:r={rate},{bands},setsar={sar}"]
def tone(frequency=440, rate=48000):
    return ["-f", "lavfi", "-i", f"sine=frequency={frequency}:sample_rate={rate}"]
# Front left only, so a correct downmix is loud on the left and silent on the right.
surround = ["-f", "lavfi", "-i", "aevalsrc=0.5*sin(2*PI*440*t)|0|0|0|0|0:c=5.1:s=48000"]
x264 = ["-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p"]
two_tracks = ["-map", "0:v", "-map", "1:a", "-map", "2:a",
    "-metadata:s:a:0", "language=eng", "-metadata:s:a:0", "title=Main",
    "-metadata:s:a:1", "language=fra", "-metadata:s:a:1", "title=Commentary"]
clips = {
    # name: (inputs, options)
    "h264_aac_25.mp4": (picture("1280x720", 25) + tone(), x264 + ["-c:a", "aac"]),
    "hevc_ac3_23976.mkv": (picture("1280x720", "24000/1001") + tone(), ["-c:v", "libx265", "-preset", "veryfast", "-x265-params", "log-level=error", "-c:a", "ac3"]),
    "av1_opus_2997.mkv": (picture("640x360", "30000/1001") + tone(), ["-c:v", "libaom-av1", "-cpu-used", "8", "-row-mt", "1", "-crf", "40", "-c:a", "libopus"]),
    "anamorphic_169_25.mkv": (picture("720x576", 25, "64/45") + tone(rate=44100), x264 + ["-c:a", "aac"]),
    "scope_239_24.mp4": (picture("1920x804", 24) + tone(), x264 + ["-c:a", "aac"]),
    "classic_43_30.mp4": (picture("640x480", 30) + tone(), x264 + ["-c:a", "aac"]),
    "silent_169_30.mp4": (picture("640x360", 30), x264),
    "surround_51_25.mkv": (picture("640x360", 25) + surround, x264 + ["-c:a", "ac3"]),
    "two_tracks_25.mkv": (picture("640x360", 25) + tone() + tone(880), two_tracks + x264 + ["-c:a", "aac"]),
    # Long enough for a resume point (positions under 10 s are not kept).
    "library/long_43_25.mp4": (picture("320x240", 25) + tone(), x264 + ["-c:a", "aac"], 60),
    "library/Episode 2.mkv": (picture("320x240", 25) + tone(), x264 + ["-c:a", "aac"]),
    "library/Episode 10.mkv": (picture("320x240", 25) + tone(), x264 + ["-c:a", "aac"]),
    "library/Season 1/Pilot.mp4": (picture("320x240", 25) + tone(), x264 + ["-c:a", "aac"]),
}
for name, (inputs, options, *length) in clips.items():
    (root / name).parent.mkdir(parents=True, exist_ok=True)
    seconds = str(length[0] if length else 4)
    command = [ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y"] + inputs + ["-t", seconds] + options + [str(root / name)]
    subprocess.run(command, check=True)
    print("made", root / name)
# Other files in a video folder are ignored.
(root / "library" / "notes.txt").write_text("not a video\n")
