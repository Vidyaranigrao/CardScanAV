//
//  PaymentCardExtractionViewController.swift
//  PaymentCardScanner


import UIKit
import AVFoundation
import Vision

class PaymentCardExtractionViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let captureSession = AVCaptureSession()
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        preview.videoGravity = .resizeAspect
        return preview
    }()
    let videoOutput = AVCaptureVideoDataOutput()
    
    // MARK: - Instance dependencies
    
    let resultsHandler: (String) -> ()
    let requestHandler = VNSequenceRequestHandler()
    var rectangleDrawing: CAShapeLayer?
    var paymentCardRectangleObservation: VNRectangleObservation?
    var viewGuide: PartialTransparentView!
    var labelCardNumber: UILabel?
    var labelHintBottom: UILabel?
    var labelHintTop: UILabel?
    var buttonComplete: UIButton?
    var buttonCancel: UIButton?
    var creditCardNumber: String?
    
    // MARK: - Initializers
    
    init(resultsHandler: @escaping (String) -> ()) {
        self.resultsHandler = resultsHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = UIView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCaptureSession()
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.bounds
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        self.extractPaymentCardNumber(frame: frame)
    }
    
    // MARK: - Camera setup
    
    private func setupCaptureSession() {
        self.addCameraInput()
        self.addPreviewLayer()
        self.addVideoOutput()
        self.addGuideView()
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.default(for: .video) else
        {
            return
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        captureSession.addInput(cameraInput)
    }
    
    private func addPreviewLayer() {
        view.layer.addSublayer(previewLayer)
    }
    
    private func addVideoOutput() {
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString: NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "image.handling.queue"))
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else {
            return
        }
        connection.videoOrientation = .portrait
    }
    
    private func addGuideView() {
        let width = UIScreen.main.bounds.width - (UIScreen.main.bounds.width * 0.2)
        let height = width - (width * 0.45)
        let viewX = (UIScreen.main.bounds.width / 2) - (width / 2)
        let viewY = (UIScreen.main.bounds.height / 2) - (height / 2) - 100
        viewGuide = PartialTransparentView(rectsArray: [CGRect(x: viewX, y: viewY, width: width, height: height)])
        
        view.addSubview(viewGuide)
        viewGuide.translatesAutoresizingMaskIntoConstraints = false
        viewGuide.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        viewGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        viewGuide.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        viewGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        view.bringSubviewToFront(viewGuide)
        
        let bottomY = (UIScreen.main.bounds.height / 2) + (height / 2) - 100

        let labelCardNumberX = viewX + 20
        let labelCardNumberY = bottomY - 50
        labelCardNumber = UILabel(frame: CGRect(x: labelCardNumberX, y: labelCardNumberY, width: 100, height: 30))
        view.addSubview(labelCardNumber!)
        labelCardNumber?.translatesAutoresizingMaskIntoConstraints = false
        labelCardNumber?.leftAnchor.constraint(equalTo: view.leftAnchor, constant: labelCardNumberX).isActive = true
        labelCardNumber?.topAnchor.constraint(equalTo: view.topAnchor, constant: labelCardNumberY).isActive = true
        labelCardNumber?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        labelCardNumber?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(clearCardNumber)))
        labelCardNumber?.isUserInteractionEnabled = true
        labelCardNumber?.textColor = .white
        
        let labelHintBottomY = bottomY + 30
        labelHintBottom = UILabel(frame: CGRect(x: labelCardNumberX, y: labelCardNumberY, width: width, height: 30))
        view.addSubview(labelHintBottom!)
        labelHintBottom?.translatesAutoresizingMaskIntoConstraints = false
        labelHintBottom?.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20).isActive = true
        labelHintBottom?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        labelHintBottom?.topAnchor.constraint(equalTo: view.topAnchor, constant: labelHintBottomY).isActive = true
        labelHintBottom?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        labelHintBottom?.text = "Touch a recognized value to delete the value and try again"
        labelHintBottom?.numberOfLines = 0
        labelHintBottom?.textAlignment = .center
        labelHintBottom?.textColor = .white

        let buttonCompleteX = viewX
        let buttonCompleteY = UIScreen.main.bounds.height - 90
        buttonComplete = UIButton(frame: CGRect(x: buttonCompleteX, y: buttonCompleteY, width: 100, height: 50))
        view.addSubview(buttonComplete!)
        buttonComplete?.translatesAutoresizingMaskIntoConstraints = false
        buttonComplete?.leftAnchor.constraint(equalTo: view.leftAnchor, constant: viewX).isActive = true
//        buttonComplete?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: viewX * -1).isActive = true
        buttonComplete?.widthAnchor.constraint(equalToConstant: 100).isActive = true
        buttonComplete?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90).isActive = true
        buttonComplete?.heightAnchor.constraint(equalToConstant: 50).isActive = true
        buttonComplete?.setTitle("Confirm", for: .normal)
        buttonComplete?.backgroundColor = .blue
        buttonComplete?.layer.cornerRadius = 10
        buttonComplete?.layer.masksToBounds = true
        buttonComplete?.addTarget(self, action: #selector(scanCompleted), for: .touchUpInside)
        
        buttonCancel = UIButton(frame: CGRect(x: buttonCompleteX + 120, y: buttonCompleteY, width: 100, height: 50))
        view.addSubview(buttonCancel!)
        buttonCancel?.translatesAutoresizingMaskIntoConstraints = false
        buttonCancel?.leftAnchor.constraint(equalTo: view.leftAnchor, constant: buttonCompleteX + 120).isActive = true
//        buttonCancel?.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: viewX * -1).isActive = true
        buttonCancel?.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90).isActive = true
        buttonCancel?.widthAnchor.constraint(equalToConstant: 100).isActive = true
        buttonCancel?.heightAnchor.constraint(equalToConstant: 50).isActive = true
        buttonCancel?.setTitle("Cancel", for: .normal)
        buttonCancel?.backgroundColor = .blue
        buttonCancel?.layer.cornerRadius = 10
        buttonCancel?.layer.masksToBounds = true
        buttonCancel?.addTarget(self, action: #selector(cancelScan), for: .touchUpInside)
    }
    
    @objc func clearCardNumber() {
        labelCardNumber?.text = ""
        creditCardNumber = nil
    }
    
    @objc func scanCompleted() {
        stopSession()
        if let cn = creditCardNumber {
            self.resultsHandler(cn)
        }
    }
    
    @objc func cancelScan() {
        stopSession()
        dismiss(animated: true, completion: nil)
    }
    
    private func stopSession() {
        captureSession.stopRunning()
    }
    
    private func getCroppedImage(_ frame: CVImageBuffer) -> CIImage {
        let ciImage = CIImage(cvImageBuffer: frame)
        let widht = UIScreen.main.bounds.width - (UIScreen.main.bounds.width * 0.2)
        let height = widht - (widht * 0.45)
        let viewX = (UIScreen.main.bounds.width / 2) - (widht / 2)
        let viewY = (UIScreen.main.bounds.height / 2) - (height / 2) - 100 + height

        let resizeFilter = CIFilter(name: "CILanczosScaleTransform")!

        // Desired output size
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)

        // Compute scale and corrective aspect ratio
        let scale = targetSize.height / ciImage.extent.height
        let aspectRatio = targetSize.width / (ciImage.extent.width * scale)

        // Apply resizing
        resizeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        let outputImage = resizeFilter.outputImage

        let croppedImage = outputImage!.cropped(to: CGRect(x: viewX, y: viewY, width: widht, height: height))
        return croppedImage
    }
    
    private func isOnlyNumbers(_ cardNumber: String) -> Bool {
        return !cardNumber.isEmpty && cardNumber.range(of: "[^0-9]", options: .regularExpression) == nil
    }
    
    private func extractPaymentCardNumber(frame: CVImageBuffer) {
        let croppedImage = getCroppedImage(frame)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let stillImageRequestHandler = VNImageRequestHandler(ciImage: croppedImage, options: [:])
        try? stillImageRequestHandler.perform([request])
        guard let texts = request.results, texts.count > 0 else {
            // no text detected
            return
        }
        
        let cardInfo = texts.flatMap({ $0.topCandidates(100).map({ $0.string }) })

        for obj in cardInfo {

            let trimmed = obj.replacingOccurrences(of: " ", with: "")

            if creditCardNumber == nil &&
                trimmed.count >= 15 &&
                trimmed.count <= 16 &&
                isOnlyNumbers(trimmed) {
                creditCardNumber = obj
                DispatchQueue.main.async {
                    self.labelCardNumber?.text = obj
                }
            }
        }
    }
}

class PartialTransparentView: UIView {
    var rectsArray: [CGRect]?

    convenience init(rectsArray: [CGRect]) {
        self.init()

        self.rectsArray = rectsArray

        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        backgroundColor?.setFill()
        UIRectFill(rect)

        guard let rectsArray = rectsArray else {
            return
        }

        for obj in rectsArray {
            let path = UIBezierPath(roundedRect: obj, cornerRadius: 10)

            let intersection = rect.intersection(obj)

            UIRectFill(intersection)

            UIColor.clear.setFill()
            UIGraphicsGetCurrentContext()?.setBlendMode(CGBlendMode.copy)
            path.fill()
        }
    }
}
