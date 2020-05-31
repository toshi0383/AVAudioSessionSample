import AVFoundation
import UIKit

final class ViewController: UIViewController {

    private let player = AVPlayer()

    private var isInteractingWithAudioSession = false {
        didSet {
            view.isUserInteractionEnabled = !isInteractingWithAudioSession
            log("block interaction: \(isInteractingWithAudioSession)")
        }
    }

    private var isActive: Bool = false {
        didSet {

            label.text = isActive ? "playing" : "paused"
            let systemName = isActive ? "pause.rectangle.fill" : "play.rectangle.fill"
            let image = UIImage(systemName: systemName)
            imageView.image = image

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

    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var label: UILabel! {
        didSet {
            label.text = nil
        }
    }

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

        UIView.animate(withDuration: 0.3, animations: {
            self.view.backgroundColor = .systemGray6
        }) { _ in
            UIView.animate(withDuration: 0.2, animations: {
                self.view.backgroundColor = .systemBackground
            })
        }
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
