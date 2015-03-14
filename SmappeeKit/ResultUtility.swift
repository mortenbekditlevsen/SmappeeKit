//
//  ResultUtility.swift
//  SmappeeKit
//
//  Created by Morten Bek Ditlevsen on 14/03/15.
//  Copyright (c) 2015 Mojo Apps. All rights reserved.
//

import Foundation
import LlamaKit

func mapOrFail<T,U,E> (array: [T], transform: (T) -> Result<U,E>) -> Result<[U],E> {
    var result = [U]()
    for element in array {
        switch transform(element) {
        case .Success(let box):
            result.append(box.unbox)
        case .Failure(let box):
            return failure(box.unbox)
        }
    }
    return success(result)
}
