//
//  ViewControllerUIKit.swift
//  BanubaAgoraFilters
//
//  Created by Max Cobb on 24/02/2022.
//

import UIKit
import AgoraRtcKit
import AgoraUIKit
import BanubaFiltersAgoraExtension
import AVKit

private struct Defaults {
  static let renderSize = AgoraVideoDimension640x480
}

class ViewControllerUIKit: UIViewController {

  var effectSelectorView: BanubaEffectSelectorView!

  private var agoraUIKit: AgoraVideoViewer?

  override func viewDidLoad() {
    super.viewDidLoad()

    setupEngine()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    startAgora()
    showVoiceOptions()
    setupEffectSelectorView()
  }

  private func setupEngine() {
    let config = AgoraRtcEngineConfig()
    config.appId = AppKeys.agoraAppID

    var agSettings = AgoraSettings()
    agSettings.videoRenderMode = .hidden
    agSettings.rtmEnabled = false
    agSettings.videoConfiguration = AgoraVideoEncoderConfiguration(
      size: Defaults.renderSize,
      frameRate: .fps30,
      bitrate: AgoraVideoBitrateStandard,
      orientationMode: .adaptative,
      mirrorMode: .auto
    )
    agSettings.enabledButtons = []
//    agSettings.buttonPosition = .right

    self.agoraUIKit = AgoraVideoViewer(
      connectionData: AgoraConnectionData(
        appId: AppKeys.agoraAppID, rtcToken: AppKeys.agoraClientToken
      ), agoraSettings: agSettings, delegate: self
    )
    self.agoraUIKit?.agkit.enableExtension(
      withVendor: "Voicemod", extension: "VoicemodExtension", enabled: true
    )
    self.agoraUIKit?.fills(view: self.view)
  }

  func startAgora() {
    if Date().compare(Date(timeIntervalSince1970: 1666089215)) == .orderedDescending {
      let alert = UIAlertController(
        title: "App Expired!",
        message: "This app was an extension demo for RTE 2022." +
                 "\nPlease go to Agora's Extensions Marketplace to find out more",
        preferredStyle: .alert)
      alert.addAction(.init(title: "Go to Agora", style: .default, handler: { action in
        UIApplication.shared.open(URL(
            string: "https://www.agora.io/en/agora-extensions-marketplace/"
        )!)
      }))
      self.present(alert, animated: true)
      return
    }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      self.joinChannel()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        if granted {
          AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
              self.joinChannel()
            }
          }
        }
      }
    case .denied, .restricted:
      let alert = UIAlertController(title: "Camera Access", message: "To proceed, you must allow camera access", preferredStyle: .alert)
      self.present(alert, animated: true) {
        fatalError("Could not get camera access")
      }
    @unknown default:
      fatalError("unknown video status")
    }
  }

  func registerVoicemod() {
    // Set API Credentials
    let dataDict = [
      "apiKey": VoicemodSettings.voicemodApiKey,
      "apiSecret": VoicemodSettings.voicemodApiSecret
    ]
    guard let encodedData = try? JSONEncoder().encode(dataDict),
          let dataString = String(data: encodedData, encoding: .utf8)  else {
        return
    }
    guard let setPropertyResp = self.agoraUIKit?.agkit
            .setExtensionPropertyWithVendor(
              "Voicemod", extension: "VoicemodExtension",
              key: "vcmd_user_data", value: dataString
            ), setPropertyResp == 0 else {
      print("Could not set extension property")
      return
    }

    let vmRtn = self.agoraUIKit?.agkit.setExtensionPropertyWithVendor(
      "Voicemod", extension: "VoicemodExtension", key: "vcmd_background_sounds", value: "false"
    )

      print("vmRtn")
      print(vmRtn)

    VoicemodSettings.voicemodRegistered = true
  }
  var voicemodSegment: UISegmentedControl!
  func showVoiceOptions() {
    let controller = UISegmentedControl(items: VoicemodSettings.voices)
    self.view.addSubview(controller)
    controller.selectedSegmentIndex = 1
    controller.addTarget(self, action: #selector(voiceModChanged(sender:)), for: .valueChanged)
    //    controllerChanged(sender: controller)
    controller.translatesAutoresizingMaskIntoConstraints = false
    controller.bottomAnchor.constraint(
      equalTo: self.view.safeAreaLayoutGuide.bottomAnchor,
      constant: -10
    ).isActive = true
    controller.widthAnchor.constraint(
      lessThanOrEqualTo: self.view.safeAreaLayoutGuide.widthAnchor).isActive = true
    controller.centerXAnchor.constraint(
      equalTo: self.view.safeAreaLayoutGuide.centerXAnchor).isActive = true
    self.voicemodSegment = controller
  }

  @objc func voiceModChanged(sender: UISegmentedControl) {
    if sender.selectedSegmentIndex == 0 {
      self.agoraUIKit?.agkit.muteLocalAudioStream(true)
      return
    }
    self.agoraUIKit?.agkit.muteLocalAudioStream(false)
    if sender.selectedSegmentIndex == 1 {
      self.agoraUIKit?.agkit.setExtensionPropertyWithVendor(
        "Voicemod", extension: "VoicemodExtension", key: "vcmd_voice", value: "null"
      )
    } else {
      if !VoicemodSettings.voicemodRegistered {
        self.registerVoicemod()
      }
      self.agoraUIKit?.agkit.setExtensionPropertyWithVendor(
        "Voicemod", extension: "VoicemodExtension",
        key: "vcmd_voice", value: "\"\(VoicemodSettings.voices[sender.selectedSegmentIndex])\""
      )
    }
  }
  private func joinChannel() {
    self.agoraUIKit?.enableExtension(
      withVendor: BanubaPluginKeys.vendorName,
      extension: BanubaPluginKeys.extensionName,
      enabled: true
    )
    self.agoraUIKit?.join(
      channel: AppKeys.agoraChannelId, with: AppKeys.agoraClientToken, uid: 0
    )
    self.agoraUIKit?.agkit.setEnableSpeakerphone(true)
    setupBanubaPlugin()
  }
}

extension ViewControllerUIKit: AgoraVideoViewerDelegate {
  func joinedChannel(channel: String) {
    // This disables mirror mode on the local user's canvas.
    if let userId = self.agoraUIKit?.userID,
       let userCanvas = self.agoraUIKit?.videoLookup[userId]?.canvas {
      userCanvas.mirrorMode = .disabled
    }
  }
}


// MARK: - EffectSelectorView
extension ViewControllerUIKit {
  private func setupEffectSelectorView() {

    self.effectSelectorView = BanubaEffectSelectorView(frame: .zero)
    self.view.addSubview(self.effectSelectorView)
    self.effectSelectorView.translatesAutoresizingMaskIntoConstraints = false
    [ self.effectSelectorView.widthAnchor.constraint(
        equalTo: self.view.safeAreaLayoutGuide.widthAnchor
      ), self.effectSelectorView.bottomAnchor.constraint(
        equalTo: self.voicemodSegment.topAnchor, constant: -10
      ), self.effectSelectorView.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor
      ), self.effectSelectorView.heightAnchor.constraint(equalToConstant: 64)
    ].forEach { $0.isActive = true }

    let resetEffectViewModel = EffectViewModel(
      image: UIImage(named: "no_effect")!,
      effectName: nil
    )
    var effectViewModels = [resetEffectViewModel]
    let effectsPath = BanubaEffectsManager.effectsURL.path
    let effectsService = EffectsService(effectsPath: effectsPath)

    effectsService
      .getEffectNames()
      .sorted()
      .forEach { effectName in
        guard let effectPreviewImage = effectsService.getEffectPreview(effectName) else {
          return
        }
        effectViewModels.append(EffectViewModel(image: effectPreviewImage, effectName: effectName))
      }
    effectSelectorView.effectViewModels = effectViewModels
    effectSelectorView.didSelectEffectViewModel = { [weak self] effectModel in
      if let effectName = effectModel.effectName {
        self?.loadEffect(effectName)
      } else {
        self?.unloadEffect()
      }
    }
    effectSelectorView.selectedEffectViewModel = effectViewModels.first
  }
}

// MARK: - BanubaFilterPlugin interactions
extension ViewControllerUIKit {
  private func setupBanubaPlugin() {
    self.agoraUIKit?.setExtensionProperty(
      BanubaPluginKeys.vendorName,
      extension: BanubaPluginKeys.extensionName,
      key: BanubaPluginKeys.setEffectsPath,
      value: BanubaEffectsManager.effectsURL.path
    )

    let clientToken = AppKeys.banubaClientToken.trimmingCharacters(in: .whitespacesAndNewlines)
    self.agoraUIKit?.setExtensionProperty(
      BanubaPluginKeys.vendorName,
      extension: BanubaPluginKeys.extensionName,
      key: BanubaPluginKeys.setToken,
      value: clientToken
    )
  }

  private func loadEffect(_ effectName: String) {
    self.agoraUIKit?.setExtensionProperty(
      BanubaPluginKeys.vendorName,
      extension: BanubaPluginKeys.extensionName,
      key: BanubaPluginKeys.loadEffect,
      value: effectName
    )
  }

  private func unloadEffect() {
    self.agoraUIKit?.setExtensionProperty(
      BanubaPluginKeys.vendorName,
      extension: BanubaPluginKeys.extensionName,
      key: BanubaPluginKeys.unloadEffect,
      value: " "
    )
  }
}

