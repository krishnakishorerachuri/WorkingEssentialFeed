//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by R krishna kishore on 13/08/25.
//

import XCTest
import EssentialFeed

class RemoteFeedLoaderTests: XCTestCase {
    
    func test_init_doesNotRequesrDattaFromURL()  {
        let client = HTTPClientSpy()
        let _ = makeSUT()
        
        XCTAssertTrue(client.requestedURLS.isEmpty)
    }
    
    func test_load_requestsDataFromURL()  {
        let url = URL(string: "https://example.com")!
        let ( sut, client) = makeSUT()
        
        sut.load{_ in }
        
        XCTAssertEqual([url], client.requestedURLS)
        
    }
    
    func test_loadTwice_requestsDataFromURLTwice()  {
        let url = URL(string: "https://example.com")!
        let ( sut, client) = makeSUT()
        
        sut.load{_ in }
        sut.load{_ in }
        XCTAssertEqual([url, url], client.requestedURLS)
        
    }
    
    func test_load_deliversErrorOnClientError() {
        let (sut, client) = makeSUT()
        expect(sut, toCompleteWithResult: failure(.connectivity),  when: {
            let clientError = NSError(domain: "Test", code: 0)
            client.complete(with: clientError, at: 0)
        })
        
    }
    
    func test_load_deliversErrorOnNon200HTTPResponse() {
        
        let (sut, client) = makeSUT()
        let samples = [199, 201, 300, 400, 500]
        samples.enumerated().forEach { index, code in
            expect(sut, toCompleteWithResult: failure(.invalidData), when: {
                let json = makeItemsJSON([])
                 client.complete(withStatusCode: code, data: json, at: index)
            })
        }
        
    }
    
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON()  {
        let (sut, client) = makeSUT()
        
        expect(sut, toCompleteWithResult: failure( .invalidData), when: {
            let invalidDataJSON = Data(bytes: "Invalid JSON".utf8)
            client.complete(withStatusCode: 200, data: invalidDataJSON, at: 0)
        })
        
    }
    
    func test_load_doesNotDeliverResultsAfterSutIsDeallocated()  {
        let url = URL(string: "https://example.com")!
        let client = HTTPClientSpy()
        var sut: RemoteFeedLoader? = RemoteFeedLoader(url: url, client: client)
        
        var capturedResults = [RemoteFeedLoader.Result]()
        sut?.load {
            capturedResults.append($0)
        }
        sut = nil
        client.complete(withStatusCode: 200, data: makeItemsJSON([]))
        
        XCTAssertTrue(capturedResults.isEmpty)
    }
    
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList()  {
        let (sut, client) = makeSUT()
        
        expect(sut, toCompleteWithResult: .success([]), when: {
            let emptyListJSON = makeItemsJSON([])
            client.complete(withStatusCode: 200, data: emptyListJSON, at: 0)
        })
        
    }
    
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems()  {
        let (sut, client) = makeSUT()
        
        let item1 = makeItem(id: UUID(),
                             description: nil,
                             location: nil,
                             imageURL: URL(string: "https://a-url.com")!)
        
        let item2 = makeItem(id: UUID(),
                             description: "a description",
                             location: "a location",
                             imageURL: URL(string: "https://another-url.com")!)
        
        let item3 = makeItem(id: UUID(),
                             description: "a description1",
                             location: "a location1",
                             imageURL: URL(string: "https://another-url1.com")!)

//        let itemsJSON = [
//            "items" : [item1.json, item2.json, item3.json]
//        ]
//        
//        print(itemsJSON)
        
        let items = [item1.model, item2.model, item3.model]
        
        expect(sut, toCompleteWithResult: .success(items), when: {
            let jsonData  = makeItemsJSON([item1.json, item2.json, item3.json])
            client.complete(withStatusCode: 200, data: jsonData, at: 0)
        })
        
    }
    
    // MARK: - Helpers
    
    private func makeSUT(url : URL = URL(string: "https://example.com")!, file : StaticString = #filePath, line : UInt = #line ) -> (sut :RemoteFeedLoader, client : HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url : url, client: client)
        
        trackForMemoryLeaks(client)
        trackForMemoryLeaks(sut)
        
        return (sut, client)
    }
    
    private func failure(_ error : RemoteFeedLoader.Error) -> RemoteFeedLoader.Result {
        return .failure(error)
    }
    
    private func makeItemsJSON(_ items : [[String : Any]]) -> Data {
        let json = ["items" : items]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func makeItem(id : UUID, description : String? = nil, location : String? = nil, imageURL : URL) -> (model :FeedItem, json : [String : Any]) {
        
        let item =  FeedItem(id: id, description: description, location: location, imageURL: imageURL)
        
        let json = [
            "id" : id.uuidString,
            "description" : description,
            "location" : location,
            "image" : imageURL.absoluteString
        ].compactMapValues{$0}
        
        return (item, json)
        
    }
    
    private func expect(_ sut : RemoteFeedLoader, toCompleteWithResult expectedResult : RemoteFeedLoader.Result, when action : () -> Void, file : StaticString = #filePath, line : UInt = #line) {
        
        let exp = expectation(description: "Wait for load expectation")
        sut.load { receivedResult in
            
            switch (receivedResult , expectedResult) {
            case let (.success(receivedItems), .success(expectedItems)):
                XCTAssertEqual(receivedItems, expectedItems, file: file, line: line)
                
            case let (.failure(receivedError as RemoteFeedLoader.Error ), .failure(expectedError as RemoteFeedLoader.Error)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
                
            default:
                XCTFail("Expected Result \(expectedResult) got Received Result \(receivedResult)", file: file, line: line)
                
            }
            
            exp.fulfill()
            
        }
        
        action()
        
        wait(for: [exp], timeout: 1.0)
        
    }
    
    private class HTTPClientSpy : HTTPClient {
        var requestedURLS :  [URL] {
            return messages.map{$0.url}
        }
        var completions = [(Error)->Void]()
        
        private var messages = [(url : URL, completion:(HTTPClientResult)-> Void)]()
        
        func get(from url : URL, completion : @escaping (HTTPClientResult)->Void  ) {
            messages.append((url, completion))
        }
        
        func complete(with error : Error, at index : Int = 0) {
            messages[index].completion(.failure(error))
        }
        
       
        
        func complete(withStatusCode code : Int, data : Data , at index : Int = 0) {
            let response = HTTPURLResponse(url: requestedURLS[index],
                                           statusCode:code ,
                                           httpVersion: nil,
                                           headerFields: nil)!
            messages[index].completion(.success(data, response))
            
        }

    }
    
}
