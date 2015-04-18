//
//  VideoPreviewView.swift
//  Swift Camera
//
//  Created by 朱 文杰 on 15/4/18.
//  Copyright (c) 2015年 Venj Chu. All rights reserved.
//

import UIKit
import AVFoundation

class VideoPreviewView: UIView {
    
    //MARK: Properties
    
    var previewLayer : AVCaptureVideoPreviewLayer {
        get {
            return self.layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    //MARK: Initializers
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _commonSetup()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
    }
    
    //MARK: View life cycle
    
    override func awakeFromNib() {
        _commonSetup()
    }
    
    //MARK: Class method
    
    override class func layerClass() -> AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    //MARK: Helper
    
    func _commonSetup() {
        let viewsDictionary = ["subView": self]
        self.superview?.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-0.0-[subView]-0.0-|", options: nil, metrics: nil, views: viewsDictionary))
        self.superview?.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0.0-[subView]-0.0-|", options: nil, metrics: nil, views: viewsDictionary))
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
    }
    
}
