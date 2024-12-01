# mpv intercept video clips

[简体中文](README.zh_CN.md) | **English**

> Helps you save unintelligible video clips when watching a video in a non-native language for easy subsequent learning



This script will match the subtitle timestamp to the current time of the video being played on the `mpv` player, use the `ffmpeg` utility to intercept the video clip, and then save the intercepted video clip to the video sibling folder.

Shortcut key `ctrl + g`.

When starting the script, try to start the script at a place where there is dialog in the video, not at a gap in the video, which may capture a long part of useless content.



**NOTE**

*The computer must have the `ffmpeg` program installed and environment variables configured.*

*Subtitle file type must be in `srt` format.*

*The subtitle file must be in the same folder as the video.*

*Subtitle file name must be the same as the video file name.*

