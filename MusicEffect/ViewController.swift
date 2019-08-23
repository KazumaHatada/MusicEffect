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

    @IBOutlet weak var osSeekBar: TappableSlider!
    @IBOutlet weak var lNowTime: UILabel!
    @IBOutlet weak var lMaxTime: UILabel!
    
    @IBOutlet weak var bStart: UIButton!
    @IBOutlet weak var bPause: UIButton!
    @IBOutlet weak var bStop: UIButton!
    
    @IBOutlet weak var lVolume: UILabel!
    
    @IBOutlet weak var bPitchFlat: UIButton!
    @IBOutlet weak var bPitchDefault: UIButton!
    @IBOutlet weak var bPitchHash: UIButton!
    @IBOutlet weak var lPitch: UILabel!
    
    //------------------------------------------------------------------
    let player = AVAudioPlayerNode()
    let engine = AVAudioEngine()
    let mpc = MPMusicPlayerController.systemMusicPlayer
    let timePitch = AVAudioUnitTimePitch()
    
    var currentSong:MPMediaItem?
    var currentFile:AVAudioFile?
    
    // 再生スライドバー用のタイマー。１秒ごとにupdateSlider()を実行する
    var sliderTimer: Timer?
    // シーク機能に必要
    var currentSampleRate: Double = 0.0
    var currentLength: Double = 0.0
    var currentTotalSec: Double = 0.0
    var offset = 0.0
    //------------------------------------------------------------------

    /// -------------------------------------------- MediaPicker関連 ----------------------------------------
    /// MediaPicker起動
    @IBAction func bChoose(_ sender: UIButton) {
        // MPMediaPickerControllerのインスタンスを作成
        let picker = MPMediaPickerController()
        picker.delegate = self

        // 複数選択を不可にする。（trueにすると、複数選択できる）
        picker.allowsPickingMultipleItems = false
        // 再生できない曲を非表示にする
        picker.showsCloudItems = false
        picker.showsItemsWithProtectedAssets = false

        present(picker, animated: true, completion: nil)
    }

    /// MediaPickerでアイテムを選択完了したときに呼び出される
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        
        // 選択した曲から最初の曲の情報を表示
        if let mi = mediaItemCollection.items.first {
            prepareEngine(mi)
            currentSong = mi
            updateUI(mi)
        }
        
        dismiss(animated: true, completion: nil)
        
        // タイマーが動いてたら止める
        sliderTimer?.invalidate()
    }
    
    /// 選択がキャンセルされた場合に呼ばれる
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    /// 再生中の曲が変更になったときに呼ばれる？呼ばれない？
    @objc func nowPlayingItemChanged(notification: NSNotification) {
        print("Item has been changed")
        if let mediaItem = mpc.nowPlayingItem {
            updateUI(mediaItem)
        }
    }
    

    /// ---------------------------- 曲がセットされた時にAvAudioEngineを作成する --------------------------------
    func prepareEngine(_ mediaItem: MPMediaItem?) {
        print("初期処理開始。。")
        
        if mediaItem == nil {
            print("曲を選んでね")
            updateUIButtonEnable(false)
            
        } else if let fileURL = mediaItem?.assetURL {
            if let file = try? AVAudioFile(forReading: fileURL) {
                currentFile = file
                
                // ボリューム初期化
                player.volume = 0.5
                engine.attach(player)
                
                // ピッチ初期化
                changePitch(0)
                timePitch.rate = 1.0
                engine.attach(timePitch)
                
                // engineに曲とピッチ情報をセット
                engine.connect(player, to: timePitch, format: file.processingFormat)
                engine.connect(timePitch, to: engine.mainMixerNode, format: file.processingFormat)
                
                // スケジューリング
                player.scheduleFile(file, at: nil, completionHandler: nil)
                
                // エンジン起動
                try? engine.start()
                
                // スライダー初期化
                initializeSlider(file)
                
                // ボタン活性化
                updateUIButtonEnable(true)
                
                print("準備完了")
            } else {
                print("音楽ファイルがおかしい？")
                updateUIButtonEnable(false)
            }
            
        } else {
            print("クラウド上のアイテムやApple Musicから「マイミュージックに追加」したアイテムは再生できません。。")
            updateUIButtonEnable(false)
        }
        
        updateUI(mediaItem)
    }

    
    /// -------------------------------------------- シークバー関連 ----------------------------------------
    /// スライドバーで指定された所から曲を再開（演奏中１秒ごと実行）
    @IBAction func sSeekBar(_ sender: TappableSlider) {
        print("SeekBar has been changed [\(sender.value)]")
        
        if currentFile == nil {
            return
        }
        
        // シーク位置（AVAudioFramePosition）取得
        let newSampleTime = AVAudioFramePosition(currentSampleRate * Double(sender.value))
        
        // 残り時間取得（sec）
        let leftSec = currentTotalSec - Double(sender.value)
        // 残りフレーム数（AVAudioFrameCount）取得
        let framesToPlay = AVAudioFrameCount(currentSampleRate * leftSec)

        if framesToPlay > 100 {
            player.stop()
            
            // 指定の位置から再生するようスケジューリング
            player.scheduleSegment(currentFile!,
                                   startingFrame: newSampleTime,
                                   frameCount: framesToPlay,
                                   at: nil,
                                   completionHandler: nil
            )
            
            player.play()
        }
/*
        player.play(
            at: AVAudioTime(
                sampleTime: AVAudioFramePosition(currentSampleRate * Double(sender.value)),
                atRate: currentSampleRate
            )
        )
*/
        // lastRenderTimeが0になってしまうので補完する
        self.offset = Double(sender.value)
    }
    
    /// 曲の再生中、１秒ごとに呼び出される
    @objc func updateSlider(_ flg:Bool = false) {

        guard let nodeTime = player.lastRenderTime else {
            return
        }

        guard let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return
        }
        
//if flg == true {
    print("kita  \(nodeTime.hostTime)  \(Double(playerTime.sampleTime))  \(currentSampleRate)  \(offset)")
//}
        
        let currentTime = (Double(playerTime.sampleTime) / currentSampleRate) + offset
        osSeekBar.value = Float(currentTime)
        lNowTime.text = formatTimeString(TimeInterval(currentTime))

//print("\(osSeekBar.minimumValue) - \(osSeekBar.value) - \(osSeekBar.maximumValue)")
    }
    
    
    /// -------------------------------------------- 再生・停止関連 ----------------------------------------
    @IBAction func bStart(_ sender: UIButton) {
        if player.numberOfInputs == 0 {
            prepareEngine(currentSong)
        }
        player.play()
        if player.isPlaying {
            print("演奏中だよ")
        } else {
            print("鳴ってないよ。。")
        }
        
        // スライダーのつまみを動かすタイマー開始
        sliderTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.updateSlider), userInfo: nil, repeats: true)
    }
    
    
    @IBAction func bPause(_ sender: UIButton) {
        if player.isPlaying {
            player.pause()
            sliderTimer?.invalidate()
            print("一時停止中だよ")
        } else {
            player.play()
            sliderTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.updateSlider), userInfo: nil, repeats: true)
            print("また鳴りだしたよ")
        }
    }
    
    
    @IBAction func bStop(_ sender: UIButton) {
        player.stop()
        sliderTimer?.invalidate()
        lNowTime.text = "0:00:00"
        print("止まったよ")
    }

    /// -------------------------------------------- ボリューム関連 ----------------------------------------
    @IBAction func sVolumeChange(_ sender: UISlider) {
        player.volume = sender.value
        lVolume.text = String(format: "%.2f%%", player.volume * 100)
    }
    
    /// ---------------------------------------------- ピッチ関連 -----------------------------------------
    @IBAction func bPitchFlat(_ sender: Any) {
        changePitch(-1)
    }
    
    @IBAction func bPitchDefault(_ sender: Any) {
        changePitch(0)
    }
    
    @IBAction func bPitchHash(_ sender: UIButton) {
        changePitch(1)
    }

    /// ピッチ（音程）の変更を行う
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


    /// ---------------------------------------------- UI関連 -----------------------------------------
    /// 画面まわりを最新化する
    func updateUI(_ mediaItem: MPMediaItem?) {
        // 曲情報表示
        // (a ?? b は、a != nil ? a! : b を示す演算子です)
        // (aがnilの場合にはbとなります)
        lArtist.text = mediaItem?.artist ?? "--"
        lSong.text = mediaItem?.title ?? "--"
        
        // アートワーク表示
        if let artwork = mediaItem?.artwork {
            vImageView.image = artwork.image(at: vImageView.bounds.size)
        } else {
            // アートワークがないとき
            vImageView.image = nil
            vImageView.backgroundColor = UIColor.gray
        }

        lVolume.text = String(format: "%.2f%%", player.volume * 100)
    }

    /// スライダーだけは別関数で。。
    func initializeSlider(_ file:AVAudioFile) {
        currentSampleRate = file.fileFormat.sampleRate // サンプルレート(Double)
        currentLength = Double(file.length) // 音声ファイルの総フレーム数(AVAudioFramePosition:Int64)
        currentTotalSec = currentLength / currentSampleRate
print("sampleRate[\(currentSampleRate)] length[\(currentLength)] totalSec[\(currentTotalSec)]")
        
        // 再生する音楽の長さとスライダーの長さを同期させる
        osSeekBar.maximumValue = Float(currentTotalSec)
        
        osSeekBar.value = 0.0
        offset = 0.0
        lMaxTime.text = formatTimeString(currentTotalSec)
        lNowTime.text = "0:00:00"
print("osSeekBar.maximumValue [\(osSeekBar.maximumValue)]")
    }

    /// ボタンの有効無効を切り替える
    func updateUIButtonEnable(_ isEnable:Bool) {
        bStart.isEnabled = isEnable
        bPause.isEnabled = isEnable
        bStop.isEnabled = isEnable
        bPitchFlat.isEnabled = isEnable
        bPitchDefault.isEnabled = isEnable
        bPitchHash.isEnabled = isEnable
    }

    
    /// ----------------------------------- ★★★★ここから呼び出される〜★★★★ -----------------------------------
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
    func formatTimeString(_ d: TimeInterval) -> String {
        var targetTime = d
        
        let hour = floor(targetTime / 3600)
        let strHour = String(format: "%d", Int(hour))
        
        targetTime = targetTime.truncatingRemainder(dividingBy: 3600)
        
        let minute = floor(targetTime / 60)
        let strMinute = String(format: "%02d", Int(minute))
        
        let second = targetTime.truncatingRemainder(dividingBy: 60)
        let strSecond = String(format: "%02d", Int(second))
        
        return String("\(strHour):\(strMinute):\(strSecond)")
    }
}

class TappableSlider: UISlider {
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        return true // どんなtouchでもスライダー調節を行う
    }
}
