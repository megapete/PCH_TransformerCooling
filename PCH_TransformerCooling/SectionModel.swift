//
//  SectionModel.swift
//  PCH_TransformerCooling
//
//  Created by PeterCoolAssHuber on 2018-09-11.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

import Cocoa

class SectionModel: NSObject {
    
    enum InletLocation {
        case inner
        case outer
    }
    var discs:[DiscModel] = []
    
    let numAxialColumns:Int
    let blockWidth:Double
    
    var inletLoc:InletLocation
    
    init(numAxialColumns:Int, blockWidth:Double, inletLoc:InletLocation = .inner, discs:[DiscModel] = [])
    {
        self.numAxialColumns = numAxialColumns
        self.blockWidth = blockWidth
        self.discs = discs
        self.inletLoc = inletLoc
    }

}
