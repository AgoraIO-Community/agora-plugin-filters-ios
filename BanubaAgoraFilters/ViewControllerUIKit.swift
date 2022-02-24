//
//  ViewControllerUIKit.swift
//  BanubaAgoraFilters
//
//  Created by Max Cobb on 24/02/2022.
//

import UIKit
import AgoraRtcKit
import AgoraUIKit_iOS
import BanubaFiltersAgoraExtension

private struct Defaults {
  static let renderSize = AgoraVideoDimension640x480
}

class ViewControllerUIKit: UIViewController {

  var effectSelectorView: BanubaEffectSelectorView!

  private var agoraUIKit: AgoraVideoViewer?

  override func viewDidLoad() {
    super.viewDidLoad()

    setupEngine()
    setupEffectSelectorView()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    joinChannel()
    setupBanubaPlugin()
  }

  private func setupEngine() {
    let config = AgoraRtcEngineConfig()
    config.appId = AppKeys.agoraAppID

    var agSettings = AgoraSettings()
    agSettings.rtmEnabled = false
    agSettings.videoConfiguration = AgoraVideoEncoderConfiguration(
      size: Defaults.renderSize,
      frameRate: .fps30,
      bitrate: AgoraVideoBitrateStandard,
      orientationMode: .adaptative,
      mirrorMode: .auto
    )
    agSettings.enabledButtons = []

    self.agoraUIKit = AgoraVideoViewer(
      connectionData: AgoraConnectionData(appId: AppKeys.agoraAppID, rtcToken: AppKeys.agoraClientToken),
      agoraSettings: agSettings,
      delegate: self
    )
    self.agoraUIKit?.enableExtension(
      withVendor: BanubaPluginKeys.vendorName,
      extension: BanubaPluginKeys.extensionName,
      enabled: true
    )
    self.agoraUIKit?.fills(view: self.view)
  }


  private func joinChannel() {
    self.agoraUIKit?.join(
      channel: AppKeys.agoraChannelId, with: AppKeys.agoraClientToken, uid: 0
    )
    self.agoraUIKit?.agkit.setEnableSpeakerphone(true)
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
        equalTo: self.view.safeAreaLayoutGuide.bottomAnchor
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

