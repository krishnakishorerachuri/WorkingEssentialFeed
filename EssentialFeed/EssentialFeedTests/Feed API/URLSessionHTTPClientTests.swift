//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by R krishna kishore on 24/08/25.
//

import XCTest
import EssentialFeed

class URLSessionHTTPClient {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func get(from url : URL, completion : @escaping (HTTPClientResult) -> Void) {
        session.dataTask(with: url) { _, _,  error in
            if let error = error{
                completion(.failure( error))
            }
        }.resume()
    }
}

final class URLSessionHTTPClientTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        URLProtocolStub.startIntercepting()

    }
    
    override class func tearDown() {
        super.tearDown()
        URLProtocolStub.stopIntercepting()
    }
    
    func test_getFromURL_performsGETRequestWithURL() {
        let exp = expectation(description: "Wait for request to complete")
        let url = anyURL()
        URLProtocolStub.observerRequests { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }
        
        makeSUT().get(from: anyURL()) { _ in
            
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_failsOnRequestError() {
        let error = NSError(domain: "any error", code: 1)
        URLProtocolStub.stub(data: nil, response: nil, error :error)
        
        let exp = expectation(description: "Wait for completion")
        makeSUT().get(from : anyURL()) { result in
            switch result {
            case let .failure(receivedError as NSError):
                XCTAssertNotNil(receivedError)
                
            default:
                XCTFail("Expected .failure with failure \(error) but got result \(result)")
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)

    }
    
 // MARK: - Helpers
    
    private func makeSUT(file : StaticString = #file, line : UInt = #line) -> URLSessionHTTPClient {
        let sut = URLSessionHTTPClient()
        trackForMemoryLeaks(sut, file: file, line:line )
        return sut
    }
    private func anyURL() -> URL  {
        return URL(string: "https://any-url.com")!
    }

    
    private final class URLProtocolStub: URLProtocol {
        private static var stub :  Stub?
        private static var requestObserver : ((URLRequest) -> Void)?
        
        private struct Stub {
            let data : Data?
            let response : URLResponse?
            let error : Error?
        }
        
        static func stub( data : Data?, response : URLResponse?, error: Error? = nil) {
            stub = Stub(data: data, response: response, error: error)
        }
        
        static func observerRequests(observer : @escaping(URLRequest) -> Void) {
            requestObserver = observer
        }
        
        static func startIntercepting() {
            URLProtocolStub.registerClass(self)
        }
        
        static func stopIntercepting() {
            URLProtocolStub.unregisterClass(self)
            stub = nil
            requestObserver = nil

        }
        
        override class func canInit(with request: URLRequest) -> Bool {
            requestObserver?(request)
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func stopLoading() {
            
        }
        
        override func startLoading() {
            
            if let data = URLProtocolStub.stub?.data{
                client?.urlProtocol(self, didLoad: data)
            }
            
            if let response =  URLProtocolStub.stub?.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let error =  URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            }
            
            client?.urlProtocolDidFinishLoading(self)
        }
        
    }
}
