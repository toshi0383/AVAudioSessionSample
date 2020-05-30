import AVFoundation
import UIKit

final class ViewController: UIViewController {

    private let player = AVPlayer()

    private var isInteractingWithAudioSession = false {
        didSet {
            button.isUserInteractionEnabled = !isInteractingWithAudioSession
            log("block interaction: \(isInteractingWithAudioSession)")
        }
    }

    private var isActive: Bool = false {
        didSet {
            let title = isActive ? "deactivate" : "activate"
            button.setTitle(title, for: .normal)

            let isActive = self.isActive

            isInteractingWithAudioSession = !isActive

            DispatchQueue.global().async { [weak self] in
                guard let player = self?.player else { return }

                if isActive {

                    let a = AVAudioSession.sharedInstance()
                    try! a.setActive(true, options: [])
                    DispatchQueue.main.async {

                    player.play()

                        }
                } else {
                    player.pause()
                }
            }
        }
    }

    @IBOutlet weak var button: UIButton!

    private var timeControlStatusKVO: NSKeyValueObservation?
    private var rateKVO: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        let url = Bundle.main.url(forResource: "river-and-train", withExtension: "m4a")!
        let asset = AVURLAsset(url: url)

        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            let item = AVPlayerItem(asset: asset)
            guard let me = self else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                me.player.replaceCurrentItem(with: item)
                me.isActive = true
                me.observePlayer()
            }
        }

    }

    @IBAction func tap(_ sender: Any) {
        isActive = !isActive
    }

    private func observePlayer() {

        rateKVO = player.observe(\.rate) { [weak self] (_, _) in
            guard let rate = self?.player.rate else { return }

            log("rate: \(rate)")
        }

        timeControlStatusKVO = player.observe(\.timeControlStatus) { [weak self] (_, _) in

            guard let status = self?.player.timeControlStatus else { return }

            switch status {
            case .paused:
                log("timeControlStatus: paused")
                self?.deactivateAudioSessionWithDelay() { [weak self] in
                    DispatchQueue.main.async { [weak self] in
                        self?.isInteractingWithAudioSession = false
                    }
                }

            case .playing:
                log("timeControlStatus: playing")
            case .waitingToPlayAtSpecifiedRate:
                log("timeControlStatus: waitingToPlayAtSpecifiedRate")
            @unknown default:
                fatalError()
            }

        }
    }

    private func deactivateAudioSessionWithDelay(completion: (() -> ())? = nil) {

        let a = AVAudioSession.sharedInstance()

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
            do {
                try a.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                log("\(error)")
            }

            completion?()
        }
    }
}

func log(_ msg: String) {
    print("[\(Date().timeIntervalSince1970)] \(msg)")
}