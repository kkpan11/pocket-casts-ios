import AVFoundation
import PocketCastsDataModel
import Combine
import SwiftUI

class ClipPlaybackManager: ObservableObject {

    static var shared = ClipPlaybackManager()

    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval?
    @Published var duration: TimeInterval = 0

    private let normalPlaybackManager = PlaybackManager.shared
    private let downloadManager = DownloadManager.shared

    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var isSeeking: Bool = false
    private var cancellables = Set<AnyCancellable>()

    @ObservedObject var clipTime: ClipTime = ClipTime(start: 0, end: 0)

    func play(episode: BaseEpisode, clipTime: ObservedObject<ClipTime>) {
        if avPlayer != nil {
            stop()
            avPlayer = nil
        }

        normalPlaybackManager.pause()

        guard let playerItem = downloadManager.downloadParallelToStream(of: episode) else {
            return
        }

        avPlayer = AVPlayer(playerItem: playerItem)

        let startTime = clipTime.projectedValue.start.wrappedValue
        let endTime = clipTime.projectedValue.end.wrappedValue
        let playbackTime = clipTime.projectedValue.playback.wrappedValue

        let playbackCMTime = CMTime(seconds: playbackTime, preferredTimescale: .audio)

        normalPlaybackManager.activateAudioSession(completion: { [weak self] activated in
            self?.avPlayer?.seek(to: playbackCMTime)
            self?.avPlayer?.play()
        })

        isPlaying = true
        duration = endTime - startTime

        observePlaybackEnd()

        self._clipTime = clipTime

        setupTimeObserver()

        $currentTime.sink(receiveValue: { currentTime in
            if let currentTime, currentTime > 0 {
                clipTime.wrappedValue.playback = currentTime
            }
        }).store(in: &cancellables)
    }

    func seek(to time: CMTime) {
        isSeeking = true
        avPlayer?.seek(to: time) { [weak self] _ in
            self?.isSeeking = false
        }
    }

    func stop() {
        avPlayer?.pause()
        isPlaying = false
        currentTime = 0
        duration = 0
        removeTimeObserver()
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else {
                return
            }
            // Loops back to the beginning at end of clip range
            guard time.seconds < clipTime.end else {
                isSeeking = true
                avPlayer?.seek(to: CMTime(seconds: clipTime.start, preferredTimescale: .audio)) { [weak self] _ in
                    guard let self else {
                        return
                    }
                    isSeeking = false
                    avPlayer?.pause()
                    currentTime = clipTime.start
                }
                return
            }

            if !isSeeking {
                currentTime = time.seconds
            }
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func observePlaybackEnd() {
        avPlayer?.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing || status == .waitingToPlayAtSpecifiedRate)
            }
            .store(in: &cancellables)
    }
}
