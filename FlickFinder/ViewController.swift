//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        // FIX: As of Swift 2.2, using strings for selectors has been deprecated. Instead, #selector(methodName) should be used.
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."

            let methodParameters: [String:String!] = [
                Constants.FlickrParameterKeys.APIKey:Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Extras:Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.Format:Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.SafeSearch:Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.NoJSONCallback:Constants.FlickrParameterValues.DisableJSONCallback,
                Constants.FlickrParameterKeys.Text:phraseTextField.text,
                Constants.FlickrParameterKeys.Method:Constants.FlickrParameterValues.SearchMethod
            ]
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            
            let methodParameters: [String:String!] = [
                Constants.FlickrParameterKeys.APIKey:Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Extras:Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.Format:Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.SafeSearch:Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.NoJSONCallback:Constants.FlickrParameterValues.DisableJSONCallback,
                Constants.FlickrParameterKeys.Text:phraseTextField.text,
                Constants.FlickrParameterKeys.Method:Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.BoundingBox:bboxString(),
            ]
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    // lat: 48.85 lont: 2.29
    private func bboxString() -> String {
        
        if let latitude = Double(latitudeTextField.text!), let longtitude = Double(longitudeTextField.text!) {
            
            let minLongtitude = max(longtitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
            let minLatitude = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
            let maxLongtitude = min(longtitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
            let maxLatitude = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
            
            return "\(minLongtitude),\(minLatitude),\(maxLongtitude),\(maxLatitude)"
        } else {
            return "0,0,0,0"
        }
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(var methodParameters: [String:AnyObject], withPageNumber: Int) {
        
        // create session and request
        let session = NSURLSession.sharedSession()
        
        methodParameters[Constants.FlickrParameterKeys.Page] = "\(withPageNumber)"
        
        let request = NSURLRequest(URL: flickrURLFromParameters(methodParameters))
        
        print(flickrURLFromParameters(methodParameters))
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned. Try again"
                    self.photoImageView.image = nil
                }
            }
            
            // Guard: was there an error
            guard (error == nil) else {
                displayError("There was an error with your request: \(error)")
                return
            }
            
            // Guard: Did we get a successful response?
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx")
                return
            }
            
            // Guard: was there any data returned?
            guard let data = data else {
                displayError("No data was returned from the request")
                return
            }
            
            // parse the data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse the data as JSON: \(data)'")
                return
            }
            
            // Guard: did flickr return an error? (status != ok)
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String where stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr api returned an error, See error code in \(parsedResult)")
                return
            }
            
            // Guard: Is the 'photos' key in the result?
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject] else {
                displayError("Could not find key 'photos' in parsedResult: \(parsedResult)'")
                return
            }

            // Guard: Is the 'photo' key in photosDictionary?
            guard let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                displayError("Could not find key 'photo' in photosDictionary: \(photosDictionary)'")
                return
            }

            if photoArray.count == 0 {
                displayError("no photo found, try again")
                return
            } else {

                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
                let photoDictionary = photoArray[randomPhotoIndex] as [String: AnyObject]

                if let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String, let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String {

                    let imageURL = NSURL(string: imageUrlString)
                    if let imageData = NSData(contentsOfURL: imageURL!) { performUIUpdatesOnMain() {
                        self.photoImageView.image = UIImage(data: imageData)
                        self.photoTitleLabel.text = photoTitle ?? "(Untitle)"
                        self.setUIEnabled(true)
                        }
                    } else {
                        displayError("Image doesnot exist in \(imageURL)")
                    }
                }
            }
        }
    }
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: flickrURLFromParameters(methodParameters))
        
        print(flickrURLFromParameters(methodParameters))
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned. Try again"
                    self.photoImageView.image = nil
                }
            }
            
            // Guard: was there an error
            guard (error == nil) else {
                displayError("There was an error with your request: \(error)")
                return
            }
            
            // Guard: Did we get a successful response?
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx")
                return
            }
            
            // Guard: was there any data returned?
            guard let data = data else {
                displayError("No data was returned from the request")
                return
            }
            
            // parse the data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse the data as JSON: \(data)'")
                return
            }
            
            // Guard: did flickr return an error? (status != ok)
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String where stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr api returned an error, See error code in \(parsedResult)")
                return
            }
            
            // Guard: Is the 'photos' key in the result?
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject] else {
                displayError("Could not find key 'photos' in parsedResult: \(parsedResult)'")
                return
            }
            
            guard let totalPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                displayError("cannot find key '\(Constants.FlickrResponseKeys.Pages)' in \(photosDictionary)")
                return
            }
            
            let pageLimit = min(totalPages, 4)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            
            self.displayImageFromFlickrBySearch(methodParameters, withPageNumber: randomPage)

        }
        task.resume()
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}