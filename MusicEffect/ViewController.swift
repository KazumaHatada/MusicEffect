//
//  ViewController.swift
//  MusicEffect
//
//  Created by Kazuma Hatada on 2019/07/29.
//  Copyright © 2019 Kazuma Hatada. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation

class ViewController: UIViewController, MPMediaPickerControllerDelegate {

    @IBOutlet weak var vImageView: UIImageView!
    @IBOutlet weak var lArtist: UILabel!
    @IBOutlet weak var lSong: UILabel!
    @IBOutlet weak var lAlbum: UILabel!
    @IBOutlet weak var lSongStatus: UILabel!
    @IBOutlet weak var lVolume: UILabel!
    @IBOutlet weak var bStart: UIButton!
    @IBOutlet weak var bPause: UIButton!
    @IBOutlet weak var bStop: UIButton!
    @IBOutlet weak var bPitchFlat: UIButton!
    @IBOutlet weak var bPitchDefault: UIButton!
    @IBOutlet weak var bPitchHash: UIButton!
    @IBOutlet weak var lPitch: UILabel!
    
    @IBAction func bChoose(_ sender: UIButton) {
        // MPMediaPickerControllerのインスタンスを作成
        let picker = MPMediaPickerController()
        // ピッカーのデリゲートを設定
        picker.delegate = self
        // 複数選択を不可にする。（trueにすると、複数選択できる）
        picker.allowsPickingMultipleItems = false
        // ピッカーを表示する
        present(picker, animated: true, completion: nil)
    }

    /// メディアアイテムピッカーでアイテムを選択完了したときに呼び出される
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        
        // 選択した曲から最初の曲の情報を表示
        if let mi = mediaItemCollection.items.first {
            prepareEngine(mi)
            currentSong = mi
            updateSongInformationUI(mi)
        }
        
        // ピッカーを閉じ、破棄する
        dismiss(animated: true, completion: nil)
    }
    
    /// 選択がキャンセルされた場合に呼ばれる
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        // ピッカーを閉じ、破棄する
        dismiss(animated: true, completion: nil)
    }
    

    @IBAction func bStart(_ sender: UIButton) {
        if player.numberOfInputs == 0 {
            prepareEngine(currentSong) // Repeat current song
        }
        player.play()
        if player.isPlaying {
            lSongStatus.text = "演奏中だよ"
        } else {
            lSongStatus.text = "鳴ってないよ。。"
        }
    }
    
    
    @IBAction func bPause(_ sender: UIButton) {
        if player.isPlaying {
            player.pause()
            lSongStatus.text = "一時停止中だよ"
        } else {
            player.play()
            lSongStatus.text = "また鳴りだしたよ"
        }
    }
    
    
    @IBAction func bStop(_ sender: UIButton) {
        player.stop()
        lSongStatus.text = "止まったよ"
    }

    
    @IBAction func sVolumeChange(_ sender: UISlider) {
        player.volume = sender.value
        lVolume.text = String(format: "%.2f%%", player.volume * 100)
    }
    

    @IBAction func bPitchFlat(_ sender: Any) {
        changePitch(-1)
    }
    
    @IBAction func bPitchDefault(_ sender: Any) {
        changePitch(0)
    }
    
    @IBAction func bPitchHash(_ sender: UIButton) {
        changePitch(1)
    }

    func changePitch(_ value:Int){
        switch value {
        case 1:
            timePitch.pitch += 100
            break
        case -1:
            timePitch.pitch -= 100
            break
        default:
            timePitch.pitch = 0
        }
        
        var pitchText = ""
        if timePitch.pitch > 0 {
            pitchText = "＃\(Int(timePitch.pitch / 100))"
        } else if timePitch.pitch < 0 {
            pitchText = "♭\(abs(Int(timePitch.pitch / 100)))"
        } else {
            pitchText = "±0"
        }
        lPitch.text = pitchText
    }

    
    
    let player = AVAudioPlayerNode()
    let engine = AVAudioEngine()
    let mpc = MPMusicPlayerController.systemMusicPlayer
    let timePitch = AVAudioUnitTimePitch()
    
    var currentSong:MPMediaItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        prepareEngine(nil)

        // 再生中のItemが変わった時に通知を受け取る
        let notificationCenter = NotificationCenter()
        notificationCenter.addObserver(self, selector: #selector(type(of: self).nowPlayingItemChanged(notification:)), name: NSNotification.Name.MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
        // 通知の有効化
        mpc.beginGeneratingPlaybackNotifications()
    }

    func prepareEngine(_ mediaItem: MPMediaItem?) {
        lArtist.text = "--"
        lSong.text = "--"
        lAlbum.text = "--"
        vImageView.backgroundColor = UIColor.gray
        lVolume.text = String(format: "%.2f%%", 0.5 * 100)
        lSongStatus.text = "初期処理開始。。"
        
        if mediaItem == nil {
            lSongStatus.text = "曲を選んでね"
            switchPlayerEnable(false)
        } else if let fileURL = mediaItem?.assetURL {
            if let file = try? AVAudioFile(forReading: fileURL) {
                player.volume = 0.5
                engine.attach(player)
                
                changePitch(0)
                timePitch.rate = 1.0
                engine.attach(timePitch)
                
                engine.connect(player, to: timePitch, format: file.processingFormat)
                engine.connect(timePitch, to: engine.mainMixerNode, format: file.processingFormat)

                player.scheduleFile(file, at: nil, completionHandler: nil)

                try? engine.start()
                
                switchPlayerEnable(true)
                
                lVolume.text = String(format: "%.2f%%", player.volume * 100)
                lSongStatus.text = "準備完了"
            } else {
                lSongStatus.text = "音楽ファイルがおかしい？"
                switchPlayerEnable(false)
            }
        } else {
            lSongStatus.text = "クラウド上のアイテムやApple Musicから「マイミュージックに追加」したアイテムは再生できません。。"
            switchPlayerEnable(false)
        }

        updateSongInformationUI(mediaItem)
    }

    /// 曲情報を表示する
    func updateSongInformationUI(_ mediaItem: MPMediaItem?) {
        // 曲情報表示
        // (a ?? b は、a != nil ? a! : b を示す演算子です)
        // (aがnilの場合にはbとなります)
        lArtist.text = mediaItem?.artist ?? "--"
        lSong.text = mediaItem?.title ?? "--"
        lAlbum.text = mediaItem?.albumTitle ?? "--"
        
        // アートワーク表示
        if let artwork = mediaItem?.artwork {
            vImageView.image = artwork.image(at: vImageView.bounds.size)
        } else {
            // アートワークがないとき
            vImageView.image = nil
            vImageView.backgroundColor = UIColor.gray
        }
    }

    func switchPlayerEnable(_ isEnable:Bool) {
        bStart.isEnabled = isEnable
        bPause.isEnabled = isEnable
        bStop.isEnabled = isEnable
        bPitchFlat.isEnabled = isEnable
        bPitchDefault.isEnabled = isEnable
        bPitchHash.isEnabled = isEnable
    }

    /// 再生中の曲が変更になったときに呼ばれる
    @objc func nowPlayingItemChanged(notification: NSNotification) {
        if let mediaItem = mpc.nowPlayingItem {
            updateSongInformationUI(mediaItem)
        }
    }

    deinit {
        // 再生中アイテム変更に対する監視をはずす
        let notificationCenter = NotificationCenter()
        notificationCenter.removeObserver(self, name: NSNotification.Name.MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
        // ミュージックプレーヤー通知の無効化
        mpc.endGeneratingPlaybackNotifications()
    }



    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
/*
1. Add the NSAppleMusicUsageDescription key to your Info.plist file, and its corresponding value
2. Setup the AVAudioSession and the `AVAudioEngine
3. Find the URL of the media item you want to play
    (you can use MPMediaPickerController like in the example below or you can make your own MPMediaQuery)
4. Create an AVAudioFile from that URL
5. Create an AVAudioPlayerNode set to play that AVAudioFile
6. Connect the player node to the engine's output node

import UIKit
import AVFoundation
import MediaPlayer
class ViewController: UIViewController {
 
    let engine = AVAudioEngine()

    override func viewDidLoad() {
        super.viewDidLoad()
 
        let mediaPicker = MPMediaPickerController(mediaTypes: .music)
        mediaPicker.allowsPickingMultipleItems = false
        mediaPicker.showsCloudItems = false // you won't be able to fetch the URL for media items stored in the cloud
        mediaPicker.delegate = self
        mediaPicker.prompt = "Pick a track"
        present(mediaPicker, animated: true, completion: nil)
    }
 
    func startEngine(playFileAt: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)

            let avAudioFile = try AVAudioFile(forReading: playFileAt)
            let player = AVAudioPlayerNode()
 
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: avAudioFile.processingFormat)
 
            try engine.start()
            player.scheduleFile(avAudioFile, at: nil, completionHandler: nil)
            player.play()
        } catch {
            assertionFailure(String(describing: error))
        }
    }
}
extension ViewController: MPMediaPickerControllerDelegate {
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        guard let item = mediaItemCollection.items.first else {
            print("no item")
            return
        }
        print("picking \(item.title!)")
        guard let url = item.assetURL else {
            return print("no url")
        }
        
        dismiss(animated: true) { [weak self] in
            self?.startEngine(playFileAt: url)
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        dismiss(animated: true, completion: nil)
    }
}
*/
}
