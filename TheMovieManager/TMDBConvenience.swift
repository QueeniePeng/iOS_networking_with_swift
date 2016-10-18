//
//  TMDBConvenience.swift
//  TheMovieManager
//
//  Created by Jarrod Parkes on 2/11/15.
//  Copyright (c) 2015 Jarrod Parkes. All rights reserved.
//

import UIKit
import Foundation

// MARK: - TMDBClient (Convenient Resource Methods)

extension TMDBClient {
    
    // MARK: Authentication (GET) Methods
    /*
        Steps for Authentication...
        https://www.themoviedb.org/documentation/api/sessions
        
        Step 1: Create a new request token
        Step 2a: Ask the user for permission via the website
        Step 3: Create a session ID
        Bonus Step: Go ahead and get the user id 😄!
    */
    func authenticateWithViewController(hostViewController: UIViewController, completionHandlerForAuth: (success: Bool, errorString: String?) -> Void) {
        
        // chain completion handlers for each request so that they run one after the other
        getRequestToken() { (success, requestToken, errorString) in
            
            if success {
                
                // success! we have the requestToken!
                print(requestToken)
                self.requestToken = requestToken
                
                self.loginWithToken(requestToken, hostViewController: hostViewController) { (success, errorString) in
                    
                    if success {
                        self.getSessionID(requestToken) { (success, sessionID, errorString) in
                            
                            if success {
                                
                                // success! we have the sessionID!
                                self.sessionID = sessionID
                                
                                self.getUserID() { (success, userID, errorString) in
                                    
                                    if success {
                                        
                                        if let userID = userID {
                                            
                                            // and the userID 😄!
                                            self.userID = userID
                                        }
                                    }
                                    
                                    completionHandlerForAuth(success: success, errorString: errorString)
                                }
                            } else {
                                completionHandlerForAuth(success: success, errorString: errorString)
                            }
                        }
                    } else {
                        completionHandlerForAuth(success: success, errorString: errorString)
                    }
                }
            } else {
                completionHandlerForAuth(success: success, errorString: errorString)
            }
        }
    }
    
    private func getRequestToken(completionHandlerForToken: (success: Bool, requestToken: String?, errorString: String?) -> Void) {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        let method = Methods.AuthenticationTokenNew
        let parameters = [String: AnyObject]()
        
        /* 2. Make the request */
        taskForGETMethod(method, parameters: parameters) { (result, error) in
            
            /* 3. Send the desired value(s) to completion handler */
            if let error = error {
                print(error)
                completionHandlerForToken(success: false, requestToken: nil, errorString: "Login failed.(Request Token)")
            } else {
                if let requestToken = result[TMDBClient.JSONResponseKeys.RequestToken] as? String {
                    print(requestToken)
                    completionHandlerForToken(success: true, requestToken: requestToken, errorString: nil)
                } else {
                    print("Could not find \(TMDBClient.JSONResponseKeys.RequestToken) in \(result)")
                    completionHandlerForToken(success: false, requestToken: nil, errorString: "Login failed.(Request Token)")
                }
            }
        }
    }
    
    private func loginWithToken(requestToken: String?, hostViewController: UIViewController, completionHandlerForLogin: (success: Bool, errorString: String?) -> Void) {
        
        let authorizationURL = NSURL(string: "\(TMDBClient.Constants.AuthorizationURL)\(requestToken!)")
        let request = NSURLRequest(URL: authorizationURL!)
        let webAuthViewController = hostViewController.storyboard!.instantiateViewControllerWithIdentifier("TMDBAuthViewController") as! TMDBAuthViewController
        webAuthViewController.urlRequest = request
        webAuthViewController.requestToken = requestToken
        webAuthViewController.completionHandlerForView = completionHandlerForLogin
        
        let webAuthNavigationController = UINavigationController()
        webAuthNavigationController.pushViewController(webAuthViewController, animated: false)
        
        performUIUpdatesOnMain {
            hostViewController.presentViewController(webAuthNavigationController, animated: true, completion: nil)
        }
    }
    
    private func getSessionID(requestToken: String?, completionHandlerForSession: (success: Bool, sessionID: String?, errorString: String?) -> Void) {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        let parameters: [String: AnyObject!] = [TMDBClient.ParameterKeys.RequestToken: requestToken]
        let method = Methods.AuthenticationSessionNew
        
        /* 2. Make the request */
        taskForGETMethod(method, parameters: parameters) { (result, error) in
            
            /* 3. Send the desired value(s) to completion handler */
            if let error = error {
                print(error)
                completionHandlerForSession(success: true, sessionID: nil, errorString: "Login failed.(Session ID)")
            } else {
                if let sessionID = result[TMDBClient.JSONResponseKeys.SessionID] as? String {
                    completionHandlerForSession(success: true, sessionID: sessionID, errorString: nil)
                } else {
                    print("Could not find key \(TMDBClient.JSONResponseKeys.SessionID) in \(result)")
                    completionHandlerForSession(success: false, sessionID: nil, errorString: "Login failed.(Session ID)")
                }
            }
        }
    }
    
    private func getUserID(completionHandlerForUserID: (success: Bool, userID: Int?, errorString: String?) -> Void) {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        let method = Methods.Account
        let parameters: [String: AnyObject!] = [TMDBClient.ParameterKeys.SessionID: TMDBClient.sharedInstance().sessionID]
        
        /* 2. Make the request */
        taskForGETMethod(method, parameters: parameters) { (result, error) in
            
            /* 3. Send the desired value(s) to completion handler */
            if let error = error {
                print(error)
                completionHandlerForUserID(success: false, userID: nil, errorString: "Login failed.(User ID)")
            } else {
                if let user_ID = result[TMDBClient.JSONResponseKeys.UserID] as? Int {
                    completionHandlerForUserID(success: true, userID: user_ID, errorString: nil)
                } else {
                    print("Could not find key \(TMDBClient.JSONResponseKeys.UserID) in \(result)")
                    completionHandlerForUserID(success: false, userID: nil, errorString: "Login failed.(User ID)")
                }
            }
        }
    }
    
    // MARK: GET Convenience Methods
    
    func getFavoriteMovies(completionHandlerForFavMovies: (result: [TMDBMovie]?, error: NSError?) -> Void) {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        /* 2. Make the request */
        /* 3. Send the desired value(s) to completion handler */
        
    }
    
    func getWatchlistMovies(completionHandlerForWatchlist: (result: [TMDBMovie]?, error: NSError?) -> Void) {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        /* 2. Make the request */
        /* 3. Send the desired value(s) to completion handler */
        
    }
    
    func getMoviesForSearchString(searchString: String, completionHandlerForMovies: (result: [TMDBMovie]?, error: NSError?) -> Void) -> NSURLSessionDataTask? {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        /* 2. Make the request */
        /* 3. Send the desired value(s) to completion handler */
        return nil
    }
    
    func getConfig(completionHandlerForConfig: (didSucceed: Bool, error: NSError?) -> Void) {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        /* 2. Make the request */
        /* 3. Send the desired value(s) to completion handler */
        
    }
    
    // MARK: POST Convenience Methods
    
    func postToFavorites(movie: TMDBMovie, favorite: Bool, completionHandlerForFavorite: (result: Int?, error: NSError?) -> Void)  {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        /* 2. Make the request */
        /* 3. Send the desired value(s) to completion handler */
        
    }
    
    func postToWatchlist(movie: TMDBMovie, watchlist: Bool, completionHandlerForWatchlist: (result: Int?, error: NSError?) -> Void) {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        /* 2. Make the request */
        /* 3. Send the desired value(s) to completion handler */
        
    }
}