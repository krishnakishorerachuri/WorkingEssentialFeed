//
//  HTTPClient.swift
//  EssentialFeed
//
//  Created by R krishna kishore on 22/08/25.
//

import Foundation

public enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

public protocol HTTPClient {
    func get(from url : URL, completion: @escaping (HTTPClientResult)-> Void )
}
