//
//  ViewController.swift
//  PaymentCardScanner


import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var resultsLabel: UILabel!

    @IBAction func scanPaymentCard(_ sender: Any) {
        let paymentCardExtractionViewController = PaymentCardExtractionViewController(resultsHandler: { paymentCardNumber in
            self.resultsLabel.text = paymentCardNumber
            self.dismiss(animated: true, completion: nil)
        })
        paymentCardExtractionViewController.modalPresentationStyle = .fullScreen
        self.present(paymentCardExtractionViewController, animated: true, completion: nil)
    }
}

