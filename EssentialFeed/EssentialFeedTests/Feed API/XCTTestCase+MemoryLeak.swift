//
//  XCTTestCase+MemoryLeak.swift
//  EssentialFeedTests
//
//  Created by R krishna kishore on 29/08/25.
//

import XCTest

extension XCTestCase {
    
     func trackForMemoryLeaks(_ instance : AnyObject, file : StaticString = #filePath, line : UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been allocated. Potentail memory leak.", file: file, line: line)
        }
    }
    
    
}
