//
//  Presentation.swift
//  AnimationsCore
//
//  Created by Brandon Kase on 5/19/18.
//

import Foundation
import UIKit

let queue = DispatchQueue(label: "com.bkase.view.timer", attributes: .concurrent)

func snapshot(view: UIView) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
    
    view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    
    // old style: layer.renderInContext(UIGraphicsGetCurrentContext())
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image!
}

public class Recording {
    var imgs : [UIImage] = []
    var timer: DispatchSourceTimer? = nil
    weak var view: UIView? = nil
    let startTime  = Date()

    init() { }
    
    public static func startRecording(view: UIView) -> Recording {
        let s = Recording()
        
        s.timer = DispatchSource.makeTimerSource(queue: queue)
        
        s.timer!.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(0))
        
        // or, in Swift 3:
        //
        // timer?.scheduleRepeating(deadline: .now(), interval: .seconds(5), leeway: .seconds(1))
        
        s.timer!.setEventHandler {
            DispatchQueue.main.sync {
                s.imgs.append(snapshot(view: view))
            }
        }
        
        s.timer!.resume()
        s.view = view
        return s
    }
    
    public func stopRecording(name: String) {
        timer = nil

        let videoGenerator = VideoGenerator.current
        videoGenerator.scaleWidth = view!.bounds.width
        videoGenerator.fileName = "movie-" + name
        print("I think seconds", Date().timeIntervalSince(startTime))
        videoGenerator.videoDurationInSeconds = Date().timeIntervalSince(startTime)
        print("Length: ", imgs.count)
        videoGenerator.generate(withImages: imgs, andAudios: [], andType: VideoGenerator.VideoGeneratorType.single, { (progress) in
            print(progress)
        }, success: { (url) in
            print(url)
        }) { (error) in
            print(error)
        }
    }
}







//
//  AVAssetExtension.swift
//  Pods-SwiftVideoGenerator_Example
//
//  Created by DevLabs BG on 22.01.18.
//

import UIKit
import AVFoundation

extension AVAsset {
    
    func videoOrientation() -> (orientation: UIInterfaceOrientation, device: AVCaptureDevice.Position) {
        var orientation: UIInterfaceOrientation = .unknown
        var device: AVCaptureDevice.Position = .unspecified
        
        let tracks: [AVAssetTrack] = self.tracks(withMediaType: .video)
        if let videoTrack = tracks.first {
            
            let t = videoTrack.preferredTransform
            
            if (t.a == 0 && t.b == 1.0 && t.d == 0) {
                orientation = .portrait
                
                if t.c == 1.0 {
                    device = .front
                } else if t.c == -1.0 {
                    device = .back
                }
            }
            else if (t.a == 0 && t.b == -1.0 && t.d == 0) {
                orientation = .portraitUpsideDown
                
                if t.c == -1.0 {
                    device = .front
                } else if t.c == 1.0 {
                    device = .back
                }
            }
            else if (t.a == 1.0 && t.b == 0 && t.c == 0) {
                orientation = .landscapeRight
                
                if t.d == -1.0 {
                    device = .front
                } else if t.d == 1.0 {
                    device = .back
                }
            }
            else if (t.a == -1.0 && t.b == 0 && t.c == 0) {
                orientation = .landscapeLeft
                
                if t.d == 1.0 {
                    device = .front
                } else if t.d == -1.0 {
                    device = .back
                }
            }
        }
        
        return (orientation, device)
    }
    
    func writeAudioTrackToURL(URL: URL, completion: @escaping (Bool, Error?) -> ()) {
        do {
            let audioAsset = try self.audioAsset()
            audioAsset.writeToURL(URL: URL, completion: completion)
            
        } catch {
            completion(false, error)
        }
    }
    
    func writeToURL(URL: URL, completion: @escaping (Bool, Error?) -> ()) {
        guard let exportSession = AVAssetExportSession(asset: self, presetName: AVAssetExportPresetAppleM4A) else {
            completion(false, nil)
            return
        }
        
        exportSession.outputFileType = AVFileType.m4a
        exportSession.outputURL      = URL as URL
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(true, nil)
            case .unknown, .waiting, .exporting, .failed, .cancelled:
                completion(false, nil)
            }
        }
    }
    
    func audioAsset() throws -> AVAsset {
        let composition = AVMutableComposition()
        let audioTracks = tracks(withMediaType: AVMediaType.audio)
        for track in audioTracks {
            
            let compositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                try compositionTrack?.insertTimeRange(track.timeRange, of: track, at: track.timeRange.start)
            } catch {
                throw error
            }
            compositionTrack?.preferredTransform = track.preferredTransform
        }
        return composition
    }
}

//
//  ImageExtension.swift
//  VideoGeneration
//
//  Created by DevLabs BG on 25.10.17.
//  Copyright © 2017 Devlabs. All rights reserved.
//

import UIKit

extension UIImage {
    
    /// Method to scale an image to the given size while keeping the aspect ratio
    ///
    /// - Parameter newSize: the new size for the image
    /// - Returns: the resized image
    func scaleImageToSize(newSize: CGSize) -> UIImage {
        
        var scaledImageRect: CGRect = CGRect.zero
        
        let aspectWidth: CGFloat = newSize.width / size.width
        let aspectHeight: CGFloat = newSize.height / size.height
        let aspectRatio: CGFloat = min(aspectWidth, aspectHeight)
        
        scaledImageRect.size.width = size.width * aspectRatio
        scaledImageRect.size.height = size.height * aspectRatio
        
        scaledImageRect.origin.x = (newSize.width - scaledImageRect.size.width) / 2.0
        scaledImageRect.origin.y = (newSize.height - scaledImageRect.size.height) / 2.0
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        draw(in: scaledImageRect)
        let scaledImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    /// Method to get a size for the image appropriate for video (dividing by 16 without overlapping 1200)
    ///
    /// - Returns: a size fit for video
    func getSizeForVideo() -> CGSize {
        let scale = UIScreen.main.scale
        var imageWidth = 16 * ((size.width / scale) / 16).rounded(.awayFromZero)
        var imageHeight = 16 * ((size.height / scale) / 16).rounded(.awayFromZero)
        var ratio: CGFloat!
        
        if imageWidth > 1400 {
            ratio = 1400 / imageWidth
            imageWidth = 16 * (imageWidth / 16).rounded(.towardZero) * ratio
            imageHeight = 16 * (imageHeight / 16).rounded(.towardZero) * ratio
        }
        
        if imageWidth < 800 {
            ratio = 800 / imageWidth
            imageWidth = 16 * (imageWidth / 16).rounded(.awayFromZero) * ratio
            imageHeight = 16 * (imageHeight / 16).rounded(.awayFromZero) * ratio
        }
        
        if imageHeight > 1200 {
            ratio = 1200 / imageHeight
            imageWidth = 16 * (imageWidth / 16).rounded(.towardZero) * ratio
            imageHeight = 16 * (imageHeight / 16).rounded(.towardZero) * ratio
        }
        
        return CGSize(width: imageWidth, height: imageHeight)
    }
    
    
    /// Method to resize an image to an appropriate video size
    ///
    /// - Returns: the resized image
    func resizeImageToVideoSize() -> UIImage? {
        let scale = UIScreen.main.scale
        let videoImageSize = getSizeForVideo()
        let imageRect = CGRect(x: 0, y: 0, width: videoImageSize.width * scale, height: videoImageSize.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: imageRect.width, height: imageRect.height), false, scale)
        if let _ = UIGraphicsGetCurrentContext() {
            draw(in: imageRect, blendMode: .normal, alpha: 1)
            
            if let resultImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                return resultImage
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}

//
//  VideoGeneratorError.swift
//  Pods-SwiftVideoGenerator_Example
//
//  Created by DevLabs BG on 22.01.18.
//

import UIKit

public class VideoGeneratorError: NSObject, LocalizedError {
    
    public enum CustomError {
        case kFailedToStartAssetWriterError
        case kFailedToAppendPixelBufferError
        case kFailedToFetchDirectory
        case kFailedToStartAssetExportSession
        case kMissingVideoURLs
        case kFailedToReadProvidedClip
        case kUnsupportedVideoType
        case kFailedToStartReader
        case kFailedToReadVideoTrack
        case kFailedToReadStartTime
    }
    
    fileprivate var desc = ""
    fileprivate var error: CustomError
    fileprivate let kErrorDomain = "VideoGenerator"
    
    init(error: CustomError) {
        self.error = error
    }
    
    override public var description: String {
        get {
            switch error {
            case .kFailedToStartAssetWriterError:
                return "\(kErrorDomain): AVAssetWriter failed to start writing"
            case .kFailedToAppendPixelBufferError:
                return "\(kErrorDomain): AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer"
            case .kFailedToFetchDirectory:
                return "\(kErrorDomain): Can't find the Documents directory"
            case .kFailedToStartAssetExportSession:
                return "\(kErrorDomain): Can't begin an AVAssetExportSession"
            case .kMissingVideoURLs:
                return "\(kErrorDomain): Missing video paths"
            case .kFailedToReadProvidedClip:
                return "\(kErrorDomain): Couldn't read the supplied video's frames."
            case .kUnsupportedVideoType:
                return "\(kErrorDomain): Unsupported video type. Supported tyeps: .m4v, mp4, .mov"
            case .kFailedToStartReader:
                return "\(kErrorDomain): Failed to start reading video frames"
            case .kFailedToReadVideoTrack:
                return "\(kErrorDomain): Failed to read video track in asset"
            case .kFailedToReadStartTime:
                return "\(kErrorDomain): Start time can't be less then 0"
            }
        }
    }
    
    public var errorDescription: String? {
        get {
            return self.description
        }
    }
}

//
//  VideoGenerator.swift
//  VideoGeneration
//
//  Created by DevLabs BG on 7/11/17.
//  Copyright © 2017 Devlabs. All rights reserved.
//

import UIKit
import AVFoundation

public class VideoGenerator: NSObject {
    
    // MARK: --------------------------------------------------------------- Singleton properties ------------------------------------------------------------
    
    open class var current: VideoGenerator {
        struct Static {
            static var instance = VideoGenerator()
        }
        
        return Static.instance
    }
    
    // MARK: --------------------------------------------------------------- Static properties ---------------------------------------------------------------
    
    /// Public enum type to represent the video generator's available modes
    ///
    /// - single: a single type generates a video from a single image and audio files
    /// - multiple: a multiple type generates a video with multiple image/audio combinations (the first image/audio pair is combined, played then switched for the next image/audio pair)
    public enum VideoGeneratorType: Int {
        case single, multiple, singleAudioMultipleImage
        
        init() {
            self = .single
        }
    }
    
    // MARK: --------------------------------------------------------------- Public properties ---------------------------------------------------------------
    
    /// public property to set the name of the finished video file
    open var fileName = "movie"
    
    /// public property to set a multiple type video's background color
    open var videoBackgroundColor: UIColor = UIColor.black
    
    /// public property to set a width to scale the image to before generating a video (used only with .single type video generation; preferred scale: 800/1200)
    open var scaleWidth: CGFloat?
    
    /// public property to indicate if the images fed into the generator should be resized to appropriate video ratio 1200 x 1920
    open var shouldOptimiseImageForVideo: Bool = true
    
    /// public property to set the maximum length of a video
    open var maxVideoLengthInSeconds: Double?
    
    /// public property to set a width to which to resize the images for multiple video generation. Default value is 800
    open var videoImageWidthForMultipleVideoGeneration = 800
    
    /// public property to set the video duration when there is no audio
    open var videoDurationInSeconds: Double = 0
    
    // MARK: - Public methods
    
    // MARK: --------------------------------------------------------------- Generate video ------------------------------------------------------------------
    
    /**
     Public method to start a video generation
     
     - parameter progress: A block which will track the progress of the generation
     - parameter success:  A block which will be called after successful generation of video
     - parameter failure:  A blobk which will be called on a failure durring the generation of the video
     */
    open func generate(withImages _images: [UIImage], andAudios _audios: [URL], andType _type: VideoGeneratorType, _ progress: @escaping ((Progress) -> Void), success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        
        VideoGenerator.current.setup(withImages: _images, andAudios: _audios, andType: _type)
        
        /// define the input and output size of the video which will be generated by taking the first image's size
        if let firstImage = VideoGenerator.current.images.first {
            VideoGenerator.current.minSize = firstImage.size
        }
        
        let inputSize = VideoGenerator.current.minSize
        let outputSize = VideoGenerator.current.minSize
        
        /// check if the documents directory can be accessed
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            
            /// generate a video output url
            let videoOutputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("test.m4v")
            
            do {
                if FileManager.default.fileExists(atPath: videoOutputURL.path) {
                    
                    /// try to delete the old generated video
                    try FileManager.default.removeItem(at: videoOutputURL)
                }
            } catch { }
            
            do {
                /// try to create an asset writer for videos pointing to the video url
                try VideoGenerator.current.videoWriter = AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mp4)
            } catch {
                VideoGenerator.current.videoWriter = nil
                failure(error)
            }
            
            /// check if the writer is instantiated successfully
            if let videoWriter = VideoGenerator.current.videoWriter {
                
                /// create the basic video settings
                let videoSettings: [String : AnyObject] = [
                    AVVideoCodecKey  : AVVideoCodecH264 as AnyObject,
                    AVVideoWidthKey  : outputSize.width as AnyObject,
                    AVVideoHeightKey : outputSize.height as AnyObject,
                    ]
                
                /// create a video writter input
                let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
                
                /// create setting for the pixel buffer
                let sourceBufferAttributes: [String : AnyObject] = [
                    (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB) as AnyObject,
                    (kCVPixelBufferWidthKey as String): Float(inputSize.width) as AnyObject,
                    (kCVPixelBufferHeightKey as String):  Float(inputSize.height) as AnyObject,
                    (kCVPixelBufferCGImageCompatibilityKey as String): NSNumber(value: true),
                    (kCVPixelBufferCGBitmapContextCompatibilityKey as String): NSNumber(value: true)
                ]
                
                /// create pixel buffer for the input writter and the pixel buffer settings
                let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourceBufferAttributes)
                
                /// check if an input can be added to the asset
                assert(videoWriter.canAdd(videoWriterInput))
                
                /// add the input writter to the video asset
                videoWriter.add(videoWriterInput)
                
                /// check if a write session can be executed
                if videoWriter.startWriting() {
                    
                    /// if it is possible set the start time of the session (current at the begining)
                    videoWriter.startSession(atSourceTime: kCMTimeZero)
                    
                    /// check that the pixel buffer pool has been created
                    assert(pixelBufferAdaptor.pixelBufferPool != nil)
                    
                    /// create/access separate queue for the generation process
                    let media_queue = DispatchQueue(label: "mediaInputQueue", attributes: [])
                    
                    /// start video generation on a separate queue
                    videoWriterInput.requestMediaDataWhenReady(on: media_queue, using: { () -> Void in
                        
                        /// set up preliminary properties for the image count, frame count and the video elapsed time
                        let numImages = VideoGenerator.current.images.count
                        var frameCount = 0
                        var elapsedTime: Double = 0
                        
                        /// calculate the frame duration by dividing the full video duration by the number of images and rounding up the number
                        let frameDuration = CMTime(seconds: Double(VideoGenerator.current.duration / Double(VideoGenerator.current.images.count)), preferredTimescale: 600)
                        let currentProgress = Progress(exactly: Int64(VideoGenerator.current.images.count))!
                        
                        /// declare a temporary array to hold all as of yet unused images
                        var remainingPhotos = [UIImage](VideoGenerator.current.images)
                        
                        var nextStartTimeForFrame: CMTime! = CMTime(seconds: 0, preferredTimescale: 1)
                        var imageForVideo: UIImage!
                        
                        /// if the input writer is ready and we have not yet used all imaged
                        while (videoWriterInput.isReadyForMoreMediaData && frameCount < numImages) {
                            
                            if VideoGenerator.current.type == .single {
                                /// pick the next photo to be loaded
                                imageForVideo = remainingPhotos.remove(at: 0)
                                
                                /// calculate the beggining time of the next frame; if the frame is the first, the start time is 0, if not, the time is the number of the frame multiplied by the frame duration in seconds
                                nextStartTimeForFrame = frameCount == 0 ? CMTime(seconds: 0, preferredTimescale: 600) : CMTime(seconds: Double(frameCount) * frameDuration.seconds, preferredTimescale: 600)
                            } else {
                                /// get the right photo from the array
                                imageForVideo = VideoGenerator.current.images[frameCount]
                                
                                if VideoGenerator.current.type == .multiple {
                                    /// calculate the start of the frame; if the frame is the first, the start time is 0, if not, get the already elapsed time
                                    nextStartTimeForFrame = frameCount == 0 ? CMTime(seconds: 0, preferredTimescale: 1) : CMTime(seconds: Double(elapsedTime), preferredTimescale: 1)
                                    
                                    /// add the max between the audio duration time or a minimum duration to the elapsed time
                                    elapsedTime += VideoGenerator.current.audioDurations[frameCount] <= 1 ? VideoGenerator.current.minSingleVideoDuration : VideoGenerator.current.audioDurations[frameCount]
                                } else {
                                    nextStartTimeForFrame = frameCount == 0 ? CMTime(seconds: 0, preferredTimescale: 600) : CMTime(seconds: Double(elapsedTime), preferredTimescale: 600)
                                    
                                    let audio_Time = VideoGenerator.current.audioDurations[0]
                                    let total_Images = VideoGenerator.current.images.count
                                    elapsedTime += audio_Time / Double(total_Images)
                                }
                            }
                            
                            /// append the image to the pixel buffer at the right start time
                            if !VideoGenerator.current.appendPixelBufferForImage(imageForVideo, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: nextStartTimeForFrame) {
                                failure(VideoGeneratorError(error: .kFailedToAppendPixelBufferError))
                            }
                            
                            // increise the frame count
                            frameCount += 1
                            
                            // currentProgress.completedUnitCount = Int64(frameCount)
                            
                            // after each successful append of an image track the current progress
                            progress(currentProgress)
                        }
                        
                        // after all images are appended the writting shoul be marked as finished
                        videoWriterInput.markAsFinished()
                        
                        if let _maxLength = self.maxVideoLengthInSeconds {
                            videoWriter.endSession(atSourceTime: CMTime(seconds: _maxLength, preferredTimescale: 600))
                        }
                        
                        // the completion is made with a completion handler which will return the url of the generated video or an error
                        videoWriter.finishWriting { () -> Void in
                            if self.audioURLs.isEmpty {
                                if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                                    let documentDirectory = URL(fileURLWithPath: path)
                                    let newPath = documentDirectory.appendingPathComponent("\(self.fileName).m4v")
                                    
                                    do {
                                        let fileURLs = try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
                                        
                                        if fileURLs.contains(newPath) {
                                            try FileManager.default.removeItem(at: newPath)
                                        }
                                        
                                        try FileManager.default.moveItem(at: videoOutputURL, to: newPath)
                                    } catch let error {
                                        failure(error)
                                    }
                                    
                                    print("finished")
                                    success(newPath)
                                }
                            } else {
                                /// if the writing is successfull, go on to merge the video with the audio files
                                VideoGenerator.current.mergeAudio(withVideoURL: videoOutputURL, success: { (videoURL) in
                                    print("finished")
                                    success(videoURL)
                                }, failure: { (error) in
                                    failure(error)
                                })
                            }
                            
                            VideoGenerator.current.videoWriter = nil
                        }
                    })
                } else {
                    failure(VideoGeneratorError(error: .kFailedToStartAssetWriterError))
                }
            } else {
                failure(VideoGeneratorError(error: .kFailedToStartAssetWriterError))
            }
        } else {
            failure(VideoGeneratorError(error: .kFailedToFetchDirectory))
        }
    }
    
    // MARK: --------------------------------------------------------------- Merge video ---------------------------------------------------------------------
    
    /// Method to merge multiple videos
    ///
    /// - Parameters:
    ///   - videoURLs: the videos to merge URLs
    ///   - fileName: the name of the finished merged video file
    ///   - success: success block - returns the finished video url path
    ///   - failure: failure block - returns the error that caused the failure
    open class func mergeMovies(videoURLs: [URL], andFileName fileName: String, success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        let acceptableVideoExtensions = ["mov", "mp4", "m4v"]
        let _videoURLs = videoURLs.filter({ !$0.absoluteString.contains(".DS_Store") && acceptableVideoExtensions.contains($0.pathExtension.lowercased()) })
        let _fileName = fileName == "" ? "mergedMovie" : fileName
        
        /// guard against missing URLs
        guard !_videoURLs.isEmpty else {
            failure(VideoGeneratorError(error: .kMissingVideoURLs))
            return
        }
        
        var videoAssets: [AVURLAsset] = []
        var completeMoviePath: URL?
        
        for path in _videoURLs {
            if let _url = URL(string: path.absoluteString) {
                videoAssets.append(AVURLAsset(url: _url))
            }
        }
        
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            /// create a path to the video file
            completeMoviePath = URL(fileURLWithPath: documentsPath).appendingPathComponent("\(_fileName).m4v")
            
            if let completeMoviePath = completeMoviePath {
                if FileManager.default.fileExists(atPath: completeMoviePath.path) {
                    do {
                        /// delete an old duplicate file
                        try FileManager.default.removeItem(at: completeMoviePath)
                    } catch {
                        failure(error)
                    }
                }
            }
        } else {
            failure(VideoGeneratorError(error: .kFailedToFetchDirectory))
        }
        
        let composition = AVMutableComposition()
        
        if let completeMoviePath = completeMoviePath {
            
            /// add audio and video tracks to the composition
            if let videoTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid), let audioTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                
                var insertTime = CMTime(seconds: 0, preferredTimescale: 600)
                
                /// for each URL add the video and audio tracks and their duration to the composition
                for sourceAsset in videoAssets {
                    do {
                        if let assetVideoTrack = sourceAsset.tracks(withMediaType: .video).first, let assetAudioTrack = sourceAsset.tracks(withMediaType: .audio).first {
                            let frameRange = CMTimeRange(start: CMTime(seconds: 0, preferredTimescale: 1), duration: sourceAsset.duration)
                            try videoTrack.insertTimeRange(frameRange, of: assetVideoTrack, at: insertTime)
                            try audioTrack.insertTimeRange(frameRange, of: assetAudioTrack, at: insertTime)
                            
                            videoTrack.preferredTransform = assetVideoTrack.preferredTransform
                        }
                        
                        insertTime = insertTime + sourceAsset.duration
                    } catch {
                        failure(error)
                    }
                }
                
                /// try to start an export session and set the path and file type
                if let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
                    exportSession.outputURL = completeMoviePath
                    exportSession.outputFileType = AVFileType.mp4
                    exportSession.shouldOptimizeForNetworkUse = true
                    
                    /// try to export the file and handle the status cases
                    exportSession.exportAsynchronously(completionHandler: {
                        switch exportSession.status {
                        case .failed:
                            if let _error = exportSession.error {
                                failure(_error)
                            }
                            
                        case .cancelled:
                            if let _error = exportSession.error {
                                failure(_error)
                            }
                            
                        default:
                            print("finished")
                            success(completeMoviePath)
                        }
                    })
                } else {
                    failure(VideoGeneratorError(error: .kFailedToStartAssetExportSession))
                }
            }
        }
    }
    
    // MARK: --------------------------------------------------------------- Reverse video -------------------------------------------------------------------
    
    /// Method to reverse a video
    ///
    /// - Parameters:
    ///   - videoURL: the video to revert URL
    ///   - fileName: the reverted video's filename
    ///   - sound: indicates if the sound should be kept and reversed as well
    ///   - success: completion block on success - returns the audio URL
    ///   - failure: completion block on failure - returns the error that caused the failure
    open func reverseVideo(fromVideo videoURL: URL, andFileName fileName: String, withSound sound: Bool, success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let extractedAudioPath = URL(fileURLWithPath: documentsPath).appendingPathComponent("audio.m4a")
            let sourceAsset = AVURLAsset(url: videoURL, options: nil)
            self.fileName = fileName
            
            if FileManager.default.fileExists(atPath: extractedAudioPath.absoluteString) {
                do {
                    try FileManager.default.removeItem(at: extractedAudioPath)
                } catch {
                    failure(error)
                }
            }
            
            self.reverseVideoClip(videoURL: videoURL, andFileName: fileName, success: { (reversedVideo) in
                if sound {
                    sourceAsset.writeAudioTrackToURL(URL: extractedAudioPath, completion: { (extracted, error) in
                        if extracted {
                            let convertedAudioPath = URL(fileURLWithPath: documentsPath).appendingPathComponent("converted.aiff")
                            let reversedAudioPath = URL(fileURLWithPath: documentsPath).appendingPathComponent("reversedAudio.mp3")
                            self.audioURLs = [reversedAudioPath]
                            let audioAsset = AVURLAsset(url: reversedAudioPath)
                            self.audioDurations = [audioAsset.duration.seconds]
                            
                            self.convertAudio(extractedAudioPath, to: convertedAudioPath, success: { (convertedAudio) in
                                self.reverseAudio(inputUrl: convertedAudioPath, outputUrl: reversedAudioPath, success: { (reversedAudio) in
                                    self.mergeAudio(withVideoURL: reversedVideo, success: { (completeMoviePath) in
                                        
                                        var pathString = reversedAudioPath.absoluteString
                                        if pathString.contains("file://") {
                                            pathString.removeSubrange(Range(pathString.startIndex..<pathString.index(pathString.startIndex, offsetBy: 7)))
                                        }
                                        
                                        if FileManager.default.fileExists(atPath: pathString) {
                                            do {
                                                try FileManager.default.removeItem(at: reversedAudioPath)
                                            } catch {
                                                failure(error)
                                            }
                                        }
                                        
                                        success(completeMoviePath)
                                    }, failure: { (error) in
                                        failure(error)
                                    })
                                    
                                }, failure: { (error) in
                                    failure(error)
                                })
                                
                            }, failure: { (error) in
                                failure(error)
                            })
                        }
                        
                        if error != nil {
                            failure(error!)
                        }
                    })
                } else {
                    success(reversedVideo)
                }
            }, failure: { (error) in
                failure(error)
            })
        } else {
            failure(VideoGeneratorError(error: .kFailedToFetchDirectory))
        }
    }
    
    // MARK: --------------------------------------------------------------- Split video -----------------------------------------------------------------------
    
    /// Public method to split a chunk of a video into a separate file
    ///
    /// - Parameters:
    ///   - videoURL: the video-to-split's URL
    ///   - startTime: the start time of the new chunk of video (in seconds)
    ///   - endTime: the end time of the new chunk of video (in seconds)
    ///   - success: completion block on success - returns the audio URL
    ///   - failure: completion block on failure - returns the error that caused the failure
    open func splitVideo(withURL videoURL: URL, atStartTime start: Double? = nil, andEndTime end: Double? = nil, success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        if start != nil {
            guard start! >= 0.0 else {
                failure(VideoGeneratorError(error: .kFailedToReadStartTime))
                return
            }
        }
        
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            let outputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("\(fileName).m4v")
            let sourceAsset = AVURLAsset(url: videoURL, options: nil)
            let length =  CMTime(seconds: sourceAsset.duration.seconds, preferredTimescale: sourceAsset.duration.timescale)
            
            do {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    
                    try FileManager.default.removeItem(at: outputURL)
                }
            } catch { }
            
            if let exportSession = AVAssetExportSession(asset: sourceAsset, presetName: AVAssetExportPresetHighestQuality) {
                exportSession.outputURL = outputURL
                exportSession.outputFileType = AVFileType.mp4
                exportSession.shouldOptimizeForNetworkUse = true
                
                let startTime = CMTime(seconds: Double(start ?? 0), preferredTimescale: sourceAsset.duration.timescale)
                var endTime = CMTime(seconds: Double(end ?? length.seconds), preferredTimescale: sourceAsset.duration.timescale)
                
                if endTime > length {
                    endTime = length
                }
                
                let timeRange = CMTimeRange(start: startTime, end: endTime)
                
                exportSession.timeRange = timeRange
                
                /// try to export the file and handle the status cases
                exportSession.exportAsynchronously(completionHandler: {
                    switch exportSession.status {
                    case .failed:
                        if let _error = exportSession.error {
                            failure(_error)
                        }
                        
                    case .cancelled:
                        if let _error = exportSession.error {
                            failure(_error)
                        }
                        
                    default:
                        print("finished")
                        success(outputURL)
                    }
                })
            } else {
                failure(VideoGeneratorError(error: .kFailedToStartAssetExportSession))
            }
        }
    }
    
    // MARK: --------------------------------------------------------------- Initialize/Livecycle methods -----------------------------------------------------
    
    public override init() {
        super.init()
    }
    
    /**
     setup method of the class
     
     - parameter _images:     The images from which a video will be generated
     - parameter _duration: The duration of the movie which will be generated
     */
    fileprivate func setup(withImages _images: [UIImage], andAudios _audios: [URL], andType _type: VideoGeneratorType) {
        images = []
        audioURLs = []
        audioDurations = []
        duration = 0.0
        
        /// guard against missing images or audio
        guard !_images.isEmpty else {
            return
        }
        
        type = _type
        audioURLs = _audios
        self.images = _images
        /*if self.type == .single {
            if let _image = self.shouldOptimiseImageForVideo ? _images.first?.resizeImageToVideoSize() : _images.first {
                self.images = [UIImage].init(repeating: _image, count: 2)
            }
        } else {
            self.images = _images
            /*for _image in _images {
                self.images.append(_image.scaleImageToSize(newSize: CGSize(width: videoImageWidthForMultipleVideoGeneration, height: videoImageWidthForMultipleVideoGeneration)))
            }*/
        }*/
        
        switch type! {
        case .single, .singleAudioMultipleImage:
            /// guard against multiple audios in single mode
            if _audios.count != 1 {
                if let _audio = _audios.first {
                    audioURLs = [_audio]
                }
            }
        case .multiple:
            /// guard agains more then equal audio and images for multiple
            break
           /* if _audios.count != _images.count {
                let count = min(_audios.count, _images.count)
                audioURLs = Array(_audios[...(count - 1)])
                images = Array(_images[...(count - 1)])
            }*/
        }
        
        var _duration: Double = 0
        
        var audioAssets: [AVURLAsset] = []
        for url in _audios {
            audioAssets.append(AVURLAsset(url: url, options: nil))
        }
        
        /// calculate the full video duration
        for audio in audioAssets {
            if let _maxLength = maxVideoLengthInSeconds {
                _duration += round(Double(CMTimeGetSeconds(audio.duration)))
                
                if _duration < _maxLength {
                    audioDurations.append(round(Double(CMTimeGetSeconds(audio.duration))))
                } else {
                    _duration -= round(Double(CMTimeGetSeconds(audio.duration)))
                    let diff = _maxLength - _duration
                    _duration = _maxLength
                    audioDurations.append(diff)
                }
            } else {
                audioDurations.append(round(Double(CMTimeGetSeconds(audio.duration))))
                _duration += round(Double(CMTimeGetSeconds(audio.duration)))
            }
        }
        
        //let minVideoDuration = Double(CMTime(seconds: minSingleVideoDuration, preferredTimescale: 1).seconds)
        duration = videoDurationInSeconds
        
        /*if let _scaleWidth = scaleWidth {
            images = images.map({ $0.scaleImageToSize(newSize: CGSize(width: _scaleWidth, height: _scaleWidth)) })
        }*/
    }
    
    // MARK: --------------------------------------------------------------- Override methods ---------------------------------------------------------------
    
    // MARK: --------------------------------------------------------------- Private properties ---------------------------------------------------------------
    
    /// private property to store the images from which a video will be generated
    fileprivate var images: [UIImage] = []
    
    /// private property to store the different audio durations
    fileprivate var audioDurations: [Double] = []
    
    /// private property to store the audio URLs
    fileprivate var audioURLs: [URL] = []
    
    /// private property to store the duration of the generated video
    fileprivate var duration: Double! = 1.0
    
    /// private property to store a video asset writer (optional because the generation might fail)
    fileprivate var videoWriter: AVAssetWriter?
    
    /// private property video generation's type
    fileprivate var type: VideoGeneratorType?
    
    /// private property to store the minimum size for the video
    fileprivate var minSize = CGSize.zero
    
    /// private property to store the minimum duration for a single video
    fileprivate var minSingleVideoDuration: Double = 3.0
    
    /// private property to store the video resource for reversing
    fileprivate var reversedVideoURL: URL?
    
    // MARK: --------------------------------------------------------------- Private methods ---------------------------------------------------------------
    
    /// Private method to generate a movie with the selected frame and the given audio
    ///
    /// - parameter audioUrl: the audio url
    /// - parameter videoUrl: the video url
    private func mergeAudio(withVideoURL videoUrl: URL, success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        /// create a mutable composition
        let mixComposition = AVMutableComposition()
        
        /// create a video asset from the url and get the video time range
        let videoAsset = AVURLAsset(url: videoUrl, options: nil)
        let videoTimeRange = CMTimeRange(start: kCMTimeZero, duration: videoAsset.duration)
        
        /// add a video track to the composition
        let videoComposition = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        if let videoTrack = videoAsset.tracks(withMediaType: .video).first {
            do {
                /// try to insert the video time range into the composition
                try videoComposition?.insertTimeRange(videoTimeRange, of: videoTrack, at: kCMTimeZero)
            } catch {
                failure(error)
            }
            
            var duration = CMTime(seconds: 0, preferredTimescale: 1)
            
            /// add an audio track to the composition
            let audioCompositon = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            /// for all audio files add the audio track and duration to the existing audio composition
            for (index, audioUrl) in audioURLs.enumerated() {
                let audioDuration = CMTime(seconds: audioDurations[index], preferredTimescale: 1)
                
                let audioAsset = AVURLAsset(url: audioUrl)
                let audioTimeRange = CMTimeRange(start: kCMTimeZero, duration: maxVideoLengthInSeconds != nil ? audioDuration : audioAsset.duration)
                
                let shouldAddAudioTrack = maxVideoLengthInSeconds != nil ? audioDuration.seconds > 0 : true
                
                if shouldAddAudioTrack {
                    if let audioTrack = audioAsset.tracks(withMediaType: .audio).first {
                        do {
                            try audioCompositon?.insertTimeRange(audioTimeRange, of: audioTrack, at: duration)
                        } catch {
                            failure(error)
                        }
                    }
                }
                
                duration = duration + (maxVideoLengthInSeconds != nil ? audioDuration : audioAsset.duration)
            }
            
            /// check if the documents folder is available
            if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                
                /// create a path to the video file
                let videoOutputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("\(fileName).m4v")
                
                do {
                    /// delete an old duplicate file
                    try FileManager.default.removeItem(at: videoOutputURL)
                } catch { }
                
                /// try to start an export session and set the path and file type
                if let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) {
                    exportSession.outputURL = videoOutputURL
                    exportSession.outputFileType = AVFileType.mp4
                    exportSession.shouldOptimizeForNetworkUse = true
                    
                    /// try to export the file and handle the status cases
                    exportSession.exportAsynchronously(completionHandler: {
                        switch exportSession.status {
                        case .failed:
                            if let _error = exportSession.error {
                                failure(_error)
                            }
                            
                        case .cancelled:
                            if let _error = exportSession.error {
                                failure(_error)
                            }
                            
                        default:
                            let testMovieOutPutPath = URL(fileURLWithPath: documentsPath).appendingPathComponent("test.m4v")
                            
                            do {
                                if FileManager.default.fileExists(atPath: testMovieOutPutPath.absoluteString) {
                                    try FileManager.default.removeItem(at: testMovieOutPutPath)
                                }
                            } catch { }
                            
                            success(videoOutputURL)
                        }
                    })
                } else {
                    failure(VideoGeneratorError(error: .kFailedToStartAssetExportSession))
                }
            } else {
                failure(VideoGeneratorError(error: .kFailedToFetchDirectory))
            }
        } else {
            failure(VideoGeneratorError(error: .kFailedToReadVideoTrack))
        }
    }
    
    /// Private method to reverse a video clip
    ///
    /// - Parameters:
    ///   - videoURL: the video to reverse's URL
    ///   - fileName: the name of the generated video
    ///   - success: completion block on success - returns the reversed video URL
    ///   - failure: completion block on failure - returns the error that caused the failure
    private func reverseVideoClip(videoURL: URL, andFileName fileName: String?, success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        let media_queue = DispatchQueue(label: "mediaInputQueue", attributes: [])
        
        media_queue.async {
            let acceptableVideoExtensions = ["mov", "mp4", "m4v"]
            
            if !videoURL.absoluteString.contains(".DS_Store") && acceptableVideoExtensions.contains(videoURL.pathExtension) {
                let _fileName = fileName == nil ? "reversedClip" : fileName!
                
                var completeMoviePath: URL?
                let videoAsset: AVAsset! = AVURLAsset(url: videoURL)
                var videoSize = CGSize.zero
                
                if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                    /// create a path to the video file
                    completeMoviePath = URL(fileURLWithPath: documentsPath).appendingPathComponent("\(String(describing: _fileName)).m4v")
                    
                    if let completeMoviePath = completeMoviePath {
                        if FileManager.default.fileExists(atPath: completeMoviePath.path) {
                            do {
                                /// delete an old duplicate file
                                try FileManager.default.removeItem(at: completeMoviePath)
                            } catch {
                                failure(error)
                            }
                        }
                    }
                } else {
                    failure(VideoGeneratorError(error: .kFailedToFetchDirectory))
                }
                
                if let completeMoviePath = completeMoviePath {
                    
                    if let firstAssetTrack = videoAsset.tracks(withMediaType: .video).first {
                        let orientation = videoAsset.videoOrientation()
                        
                        if orientation.orientation == .portrait {
                            videoSize = CGSize(width: firstAssetTrack.naturalSize.height, height: firstAssetTrack.naturalSize.width)
                        } else {
                            videoSize = firstAssetTrack.naturalSize
                        }
                    }
                    
                    /// create setting for the pixel buffer
                    
                    let sourceBufferAttributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
                    
                    var writer: AVAssetWriter!
                    
                    do {
                        let reader = try AVAssetReader(asset: videoAsset)
                        
                        if let assetVideoTrack = videoAsset.tracks(withMediaType: .video).first {
                            
                            let videoCompositionProps = [AVVideoAverageBitRateKey: assetVideoTrack.estimatedDataRate]
                            /// create the basic video settings
                            let videoSettings: [String : Any] = [
                                AVVideoCodecKey  : AVVideoCodecH264,
                                AVVideoWidthKey  : videoSize.width,
                                AVVideoHeightKey : videoSize.height,
                                AVVideoCompressionPropertiesKey: videoCompositionProps
                            ]
                            
                            let readerOutput = AVAssetReaderTrackOutput(track: assetVideoTrack, outputSettings: sourceBufferAttributes)
                            
                            assert(reader.canAdd(readerOutput))
                            reader.add(readerOutput)
                            
                            if reader.startReading() {
                                
                                var samples: [CMSampleBuffer] = []
                                
                                while let sample = readerOutput.copyNextSampleBuffer() {
                                    samples.append(sample)
                                }
                                
                                reader.cancelReading()
                                
                                if samples.count > 1 {
                                    
                                    writer = try AVAssetWriter(outputURL: completeMoviePath, fileType: .m4v)
                                    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                                    writerInput.expectsMediaDataInRealTime = false
                                    
                                    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
                                    
                                    assert(writer.canAdd(writerInput))
                                    
                                    writer.add(writerInput)
                                    
                                    if writer.startWriting() {
                                        
                                        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(samples[0]))
                                        
                                        assert(pixelBufferAdaptor.pixelBufferPool != nil)
                                        
                                        for (index, sample) in samples.enumerated() {
                                            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)
                                            let imageBufferRef: CVPixelBuffer = CMSampleBufferGetImageBuffer(samples[samples.count - index - 1])!
                                            
                                            while (!writerInput.isReadyForMoreMediaData) {
                                                Thread.sleep(forTimeInterval: 0.05)
                                            }
                                            
                                            pixelBufferAdaptor.append(imageBufferRef, withPresentationTime: presentationTime)
                                        }
                                        
                                        writerInput.markAsFinished()
                                        
                                        DispatchQueue.main.async {
                                            writer.finishWriting(completionHandler: {
                                                success(completeMoviePath)
                                            })
                                        }
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        failure(VideoGeneratorError(error: .kFailedToReadProvidedClip))
                                    }
                                }
                            } else {
                                DispatchQueue.main.async {
                                    failure(VideoGeneratorError(error: .kFailedToStartReader))
                                }
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            failure(error)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        failure(VideoGeneratorError(error: .kFailedToFetchDirectory))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    failure(VideoGeneratorError(error: .kUnsupportedVideoType))
                }
            }
        }
    }
    
    /// Private method to convert an audio file on a given URL to linear PMC format
    ///
    /// - Parameters:
    ///   - url: The source audio url
    ///   - outputURL: Converted audio url
    private func convertAudio(_ url: URL, to outputURL: URL, success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        var error: OSStatus = noErr
        var destinationFile: ExtAudioFileRef? = nil
        var sourceFile: ExtAudioFileRef? = nil
        
        var srcFormat = AudioStreamBasicDescription()
        var dstFormat = AudioStreamBasicDescription()
        
        ExtAudioFileOpenURL(url as CFURL, &sourceFile)
        
        var thePropertySize: UInt32 = UInt32(MemoryLayout.stride(ofValue: srcFormat))
        ExtAudioFileGetProperty(sourceFile!, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &srcFormat)
        
        dstFormat.mSampleRate = 44100
        dstFormat.mFormatID = kAudioFormatLinearPCM
        dstFormat.mChannelsPerFrame = 1
        dstFormat.mBitsPerChannel = 16
        dstFormat.mBytesPerPacket = 2 * dstFormat.mChannelsPerFrame
        dstFormat.mBytesPerFrame = 2 * dstFormat.mChannelsPerFrame
        dstFormat.mFramesPerPacket = 1
        dstFormat.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger
        
        error = ExtAudioFileCreateWithURL(outputURL as CFURL, kAudioFileAIFFType, &dstFormat, nil, AudioFileFlags.eraseFile.rawValue, &destinationFile)
        
        error = ExtAudioFileSetProperty(sourceFile!, kExtAudioFileProperty_ClientDataFormat, thePropertySize, &dstFormat)
        
        error = ExtAudioFileSetProperty(destinationFile!, kExtAudioFileProperty_ClientDataFormat, thePropertySize, &dstFormat)
        
        let bufferByteSize: UInt32 = 32768
        var srcBuffer = [UInt8](repeating: 0, count: Int(bufferByteSize))
        var sourceFrameOffset: ULONG = 0
        
        while true {
            var fillBufList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(srcBuffer.count), mData: &srcBuffer))
            var numFrames: UInt32 = 0
            
            if (dstFormat.mBytesPerFrame > 0) {
                numFrames = bufferByteSize / dstFormat.mBytesPerFrame
            }
            
            error = ExtAudioFileRead(sourceFile!, &numFrames, &fillBufList)
            
            if (numFrames == 0) {
                error = noErr
                break
            }
            
            sourceFrameOffset += numFrames
            error = ExtAudioFileWrite(destinationFile!, numFrames, &fillBufList)
        }
        
        error = ExtAudioFileDispose(destinationFile!)
        error = ExtAudioFileDispose(sourceFile!)
        
        var pathString = url.absoluteString
        if pathString.contains("file://") {
            pathString.removeSubrange(Range(pathString.startIndex..<pathString.index(pathString.startIndex, offsetBy: 7)))
        }
        
        if FileManager.default.fileExists(atPath: pathString) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch { }
        }
        
        if error == noErr {
            success(url)
        } else {
            print(error)
        }
    }
    
    /// Private method to reverse an audio file
    ///
    /// - Parameters:
    ///   - inputUrl: source audio file url
    ///   - outputUrl: output reverced audio file url
    private func reverseAudio(inputUrl: URL, outputUrl: URL, success: @escaping ((URL) -> Void), failure: @escaping ((Error) -> Void)) {
        var originalAudioFile: AudioFileID?
        AudioFileOpenURL(inputUrl as CFURL, .readPermission, 0, &originalAudioFile)
        
        var outAudioFile:AudioFileID?
        var pcm = AudioStreamBasicDescription(mSampleRate: 44100.0,
                                              mFormatID: kAudioFormatLinearPCM,
                                              mFormatFlags: kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger,
                                              mBytesPerPacket: 2,
                                              mFramesPerPacket: 1,
                                              mBytesPerFrame: 2,
                                              mChannelsPerFrame: 1,
                                              mBitsPerChannel: 16,
                                              mReserved: 0)
        
        var theErr = AudioFileCreateWithURL(outputUrl as CFURL, kAudioFileAIFFType, &pcm, .eraseFile, &outAudioFile)
        
        if noErr == theErr, let outAudioFile = outAudioFile {
            var inAudioFile:AudioFileID?
            
            theErr = AudioFileOpenURL(inputUrl as CFURL, .readPermission, 0, &inAudioFile)
            
            if noErr == theErr, let inAudioFile = inAudioFile {
                
                var fileDataSize:UInt64 = 0
                var thePropertySize:UInt32 = UInt32(MemoryLayout<UInt64>.stride)
                theErr = AudioFileGetProperty(inAudioFile, kAudioFilePropertyAudioDataByteCount, &thePropertySize, &fileDataSize)
                
                if (noErr == theErr) {
                    let dataSize:Int64 = Int64(fileDataSize)
                    let theData = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<UInt8>.alignment)
                    
                    var readPoint:Int64 = Int64(dataSize)
                    var writePoint:Int64 = 0
                    
                    while readPoint > 0 {
                        var bytesToRead = UInt32(2)
                        
                        AudioFileReadBytes(inAudioFile, false, readPoint, &bytesToRead, theData)
                        AudioFileWriteBytes(outAudioFile, false, writePoint, &bytesToRead, theData)
                        
                        writePoint += 16
                        readPoint -= 16
                        
                        print(1.0 - (CGFloat(readPoint) / CGFloat(dataSize)))
                    }
                    
                    theData.deallocate()
                    
                    AudioFileClose(inAudioFile)
                    AudioFileClose(outAudioFile)
                    
                    var pathString = inputUrl.absoluteString
                    if pathString.contains("file://") {
                        pathString.removeSubrange(Range(pathString.startIndex..<pathString.index(pathString.startIndex, offsetBy: 7)))
                    }
                    
                    if FileManager.default.fileExists(atPath: pathString) {
                        do {
                            try FileManager.default.removeItem(at: inputUrl)
                        } catch {
                            failure(error)
                        }
                    }
                    
                    success(outputUrl)
                }
            }
        }
    }
    
    /**
     Private method to append pixels to a pixel buffer
     
     - parameter url:                The image which pixels will be appended to the pixel buffer
     - parameter pixelBufferAdaptor: The pixel buffer to which new pixels will be added
     - parameter presentationTime:   The duration of each frame of the video
     
     - returns: True or false depending on the action execution
     */
    private func appendPixelBufferForImage(_ image: UIImage, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        
        /// at the beginning of the append the status is false
        var appendSucceeded = false
        
        /**
         *  The proccess of appending new pixels is put inside a autoreleasepool
         */
        autoreleasepool {
            
            // check posibilitty of creating a pixel buffer pool
            if let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )
                
                /// check if the memory of the pixel buffer pointer can be accessed and the creation status is 0
                if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                    
                    // if the condition is satisfied append the image pixels to the pixel buffer pool
                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                    
                    // generate new append status
                    appendSucceeded = pixelBufferAdaptor.append(
                        pixelBuffer,
                        withPresentationTime: presentationTime
                    )
                    
                    /**
                     *  Destroy the pixel buffer contains
                     */
                    pixelBufferPointer.deinitialize(count: 1)
                } else {
                    NSLog("error: Failed to allocate pixel buffer from pool")
                }
                
                /**
                 Destroy the pixel buffer pointer from the memory
                 */
                pixelBufferPointer.deallocate()
            }
        }
        
        return appendSucceeded
    }
    
    /**
     Private method to append image pixels to a pixel buffer
     
     - parameter image:       The image which pixels will be appented
     - parameter pixelBuffer: The pixel buffer (as memory) to which the image pixels will be appended
     */
    private func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
        // lock the buffer memoty so no one can access it during manipulation
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        // get the pixel data from the address in the memory
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        // create a color scheme
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        /// set the context size
        let contextSize = image.size
        
        // generate a context where the image will be drawn
        if let context = CGContext(data: pixelData, width: Int(contextSize.width), height: Int(contextSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
            
            var imageHeight = image.size.height
            var imageWidth = image.size.width
            
            if Int(imageHeight) > context.height {
                imageHeight = 16 * (CGFloat(context.height) / 16).rounded(.awayFromZero)
            } else if Int(imageWidth) > context.width {
                imageWidth = 16 * (CGFloat(context.width) / 16).rounded(.awayFromZero)
            }
            
            let center = type == .single ? CGPoint.zero : CGPoint(x: (minSize.width - imageWidth) / 2, y: (minSize.height - imageHeight) / 2)
            
            context.clear(CGRect(x: 0.0, y: 0.0, width: imageWidth, height: imageHeight))
            
            // set the context's background color
            context.setFillColor(type == .single ? UIColor.black.cgColor : videoBackgroundColor.cgColor)
            context.fill(CGRect(x: 0.0, y: 0.0, width: CGFloat(context.width), height: CGFloat(context.height)))
            
            context.concatenate(CGAffineTransform.identity)
            
            // draw the image in the context
            
            if let cgImage = image.cgImage {
                context.draw(cgImage, in: CGRect(x: center.x, y: center.y, width: imageWidth, height: imageHeight))
            }
            
            // unlock the buffer memory
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        }
    }
}
