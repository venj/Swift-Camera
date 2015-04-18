//
//  ViewController.swift
//  Swift Camera
//
//  Created by 朱 文杰 on 15/4/18.
//  Copyright (c) 2015年 Venj Chu. All rights reserved.
//

import UIKit
import AVFoundation

class CameraPreviewController: UIViewController {
    
    //MARK: Properties
    
    @IBOutlet weak var toggleTorchButton: UIButton!
    @IBOutlet weak var switchCamButton: UIButton!
    @IBOutlet weak var snapButton: UIButton!
    
    var _camera : AVCaptureDevice!
    var _videoInput : AVCaptureDeviceInput!
    var _imageOutput : AVCaptureStillImageOutput!
    var _captureSession : AVCaptureSession!
    var _videoPreview : VideoPreviewView!
    
    //MARK: View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        assert(self.view is VideoPreviewView, "Wrong root view class \(_stdlib_getDemangledTypeName(self.view)) in \(_stdlib_getDemangledTypeName(self))")
        _videoPreview = self.view as! VideoPreviewView
        _setupCameraAfterCheckingAuthorization()
        
        // Gesture recognizer for tap-to-focus
        let tap = UITapGestureRecognizer(target: self, action: "handleTap:")
        view.addGestureRecognizer(tap)
        
        let center = NSNotificationCenter.defaultCenter()
        center.addObserver(self, selector: "subjectChanged:", name:AVCaptureDeviceSubjectAreaDidChangeNotification, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if _captureSession != nil {
            _captureSession.startRunning()
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        if _captureSession.running {
            _captureSession.stopRunning()
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //MARK: Device Rotation
    
    override func supportedInterfaceOrientations() -> Int {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            return Int(UIInterfaceOrientationMask.All.rawValue)
        }
        else {
            return Int(UIInterfaceOrientationMask.AllButUpsideDown.rawValue)
        }
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        _updateConnectionsForInterfaceOrientation(toInterfaceOrientation)
    }
    
    //MARK: Action Methods.

    @IBAction func switchCamera(sender: AnyObject) {
        _captureSession.beginConfiguration()
        _camera = _alternativeCameraToCurrent()
        
        //_configureCurrentCamera()
        
        for input in _captureSession.inputs {
            if let i = input as? AVCaptureDeviceInput {
                _captureSession.removeInput(i)
            }
        }
        
        _videoInput = AVCaptureDeviceInput.deviceInputWithDevice(_camera, error: nil) as! AVCaptureDeviceInput
        _captureSession.addInput(_videoInput)
        _updateConnectionsForInterfaceOrientation(interfaceOrientation)
        _captureSession.commitConfiguration()
        
        _setupSwitchCamButton()
        _setupTorchToggleButton()
    }

    @IBAction func snap(sender: AnyObject) {
        if _camera == nil {
            return
        }
        
        let videoConnection = _captureConnection()
        
        if let connection = videoConnection {
            _imageOutput.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (imageSampleBuffer, error) -> Void in
                if (error != nil) {
                    println("Error capturing still image: %@", error.localizedDescription)
                }
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
                let image = UIImage(data: imageData)
                UIImageWriteToSavedPhotosAlbum(image, self, "image:didFinishSavingWithError:contextInfo:", nil)
            })
        }
        else {
            println("Error: No video connection found on still image output")
            return
        }
    }
    
    @IBAction func toggleTorch(sender: AnyObject) {
        if _camera.hasTorch {
            var torchActive = _camera.torchActive
            if _camera.lockForConfiguration(nil) {
                if torchActive {
                    if _camera.isTorchModeSupported(.Off) {
                        _camera.torchMode = .Off
                    }
                }
                else {
                    if _camera.isTorchModeSupported(.On) {
                        _camera.torchMode = .On
                    }
                }
                _camera.unlockForConfiguration()
            }
        }
    }
    
    //MARK: Helper
    
    func _setupCamera() {
        _camera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        if _camera == nil {
            snapButton.setTitle("No Camera Found", forState: .Normal)
            snapButton.enabled = false
            _inforUserAboutNoCam()
        }
        
        var error:NSError?
        _videoInput = AVCaptureDeviceInput(device: _camera, error: &error)
        if _camera == nil {
            println("Error connecting video input: \(error?.description)")
        }
        
        _captureSession = AVCaptureSession()
        if _captureSession.canAddInput(_videoInput) {
            _captureSession.addInput(_videoInput)
        }
        else {
            println("Unable to add video input to capture session")
            return
        }
        
        //_configureCurrentCamera()
        
        _imageOutput = AVCaptureStillImageOutput()
        if _captureSession.canAddOutput(_imageOutput) {
            _captureSession.addOutput(_imageOutput)
        }
        else {
            println("Unable to add still image output to capture session")
            return
        }
        
        _videoPreview.previewLayer.session = _captureSession
    }
    
    // Camera authorization
    func _setupCameraAfterCheckingAuthorization() {
        if !AVCaptureDevice.respondsToSelector("authorizationStatusForMediaType:") {
            _setupCamera()
        }
        
        let authStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        
        switch authStatus {
        case .Authorized:
            _setupCamera()
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted) in
                dispatch_async(dispatch_get_main_queue(), { [self]
                    if granted {
                        self._setupCamera()
                        self._captureSession.startRunning()
                    }
                    else {
                        self._informUserAboutCamNotAuthorized()
                    }
                })
            })
        case .Restricted, .Denied:
            fallthrough
        default:
            _informUserAboutCamNotAuthorized()
        }
    }
    
    func _informUserAboutCamNotAuthorized() {
        // Show some authorization notice. Like: Alert.
    }
    
    func _inforUserAboutNoCam() {
        // Show no cam notice.
    }
    
    // Handle image save completion
    func image(image: UIImage, didFinishSavingWithError error: NSError, contextInfo:UnsafePointer<()>) {
        println("Image saved to photo library.")
    }
    
    // Ever lit flash is torch.
    func _setupTorchToggleButton() {
        if _camera.hasTorch {
            toggleTorchButton.hidden = false
        }
        else {
            toggleTorchButton.hidden = true
        }
    }
    
    // Get the video connection
    func _captureConnection() -> AVCaptureConnection? {
        for connection in _imageOutput.connections {
            if let c = connection as? AVCaptureConnection {
                for port in c.inputPorts {
                    if (port as! AVCaptureInputPort).mediaType == AVMediaTypeVideo {
                        return c
                    }
                }
            }
        }
        return nil
    }
    
    // Update avcaptureconnection orientation according to device rotation
    func _updateConnectionsForInterfaceOrientation(interfaceOrientation : UIInterfaceOrientation) {
        var videoOrientation = captureVideoOrientationForUIInterfaceOrientation(interfaceOrientation)
        
        for connection in _imageOutput.connections {
            if let c = connection as? AVCaptureConnection {
                if c.supportsVideoOrientation {
                    c.videoOrientation = videoOrientation
                }
            }
        }
        
        if _videoPreview.previewLayer.connection.supportsVideoOrientation {
            _videoPreview.previewLayer.connection.videoOrientation = videoOrientation
        }
    }
    
    // Translate device orientation to avcapturevideoorientation
    func captureVideoOrientationForUIInterfaceOrientation(interfaceOrientation : UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        var videoOrientation : AVCaptureVideoOrientation = .Portrait
        switch interfaceOrientation {
        case .LandscapeLeft:
            videoOrientation = .LandscapeLeft
        case .LandscapeRight:
            videoOrientation = .LandscapeRight
        case .PortraitUpsideDown:
            videoOrientation = .PortraitUpsideDown
        case .Portrait:
            fallthrough
        default:
            videoOrientation = .Portrait
        }
        
        return videoOrientation
    }
    
    func _setupSwitchCamButton() {
        let alternativeCam = _alternativeCameraToCurrent()
        
        if let cam = alternativeCam {
            switchCamButton.hidden = false
            var title : String
            
            switch cam.position {
            case .Back:
                title = "Back"
            case .Front:
                title = "Front"
            case .Unspecified:
                title = "Other"
            }
            
            switchCamButton.setTitle(title, forState: .Normal)
        }
        else {
            switchCamButton.hidden = true
        }
    }
    
    func _alternativeCameraToCurrent() -> AVCaptureDevice? {
        if _camera == nil {
            return nil
        }
        
        let allCameras = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        
        for cam in allCameras {
            if let c = cam as? AVCaptureDevice {
                if c != _camera {
                    return c
                }
            }
        }
        
        return nil
    }
    
    func _configureCurrentCamera() {
        if _camera.isFocusModeSupported(.Locked) {
            if _camera.lockForConfiguration(nil) {
                _camera.subjectAreaChangeMonitoringEnabled = true
                _camera.unlockForConfiguration()
            }
        }
    }
    
    func subjectChanged(nitification: NSNotification) {
        if _camera.focusMode == .Locked {
            if _camera.lockForConfiguration(nil) {
                if _camera.focusPointOfInterestSupported {
                    _camera.focusPointOfInterest = CGPointMake(0.5, 0.5)
                }
                
                if _camera.isFocusModeSupported(.ContinuousAutoFocus) {
                    _camera.focusMode = .ContinuousAutoFocus
                }
                
                println("Focus mode: Continuous")
            }
        }
    }
    
    func handleTap(gesture:UITapGestureRecognizer) {
        if gesture.state == .Ended {
            if !_camera.focusPointOfInterestSupported || !_camera.isFocusModeSupported(.AutoFocus) {
                println("Focus Point Not Supported by current camera")
                return
            }
        }
        
        let locationInPreview = gesture.locationInView(_videoPreview)
        let locationInCapture = _videoPreview.previewLayer.captureDevicePointOfInterestForPoint(locationInPreview)
        
        if _camera.lockForConfiguration(nil) {
            _camera.focusPointOfInterest = locationInCapture
            _camera.focusMode = .AutoFocus
            println("Focus Mode: Locked to Focus Point")
            _camera.unlockForConfiguration()
        }
    }
    
}

