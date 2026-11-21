import QtQuick
import QtMultimedia

// Video background, loaded only when theme.conf names a video; needs qt6-multimedia
Video {
    fillMode: VideoOutput.PreserveAspectCrop
    loops: MediaPlayer.Infinite
    muted: true
    autoPlay: true
}
