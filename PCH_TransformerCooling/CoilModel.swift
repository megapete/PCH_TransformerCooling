//
//  CoilModel.swift
//  PCH_TransformerCooling
//
//  Created by PeterCoolAssHuber on 2018-09-11.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

import Cocoa

class CoilModel: NSObject {
    
    let usesOilFlowWashers:Bool
    
    let innerDuctDimn:Double
    let numInnerSticks:Int
    let outerDuctDimn:Double
    let numOuterSticks:Int
    
    let stickWidth:Double
    
    let coilID:Double
    
    var sections:[SectionModel] = []
    
    init(coilID:Double, usesOilFlowWashers:Bool = true, innerDuctDimn:Double = 0.00635, numInnerSticks:Int, outerDuctDimn:Double = 0.00635, numOuterSticks:Int, stickWidth:Double = 0.01905, sections:[SectionModel] = [])
    {
        self.coilID = coilID
        self.usesOilFlowWashers = usesOilFlowWashers
        self.innerDuctDimn = innerDuctDimn
        self.numInnerSticks = numInnerSticks
        self.outerDuctDimn = outerDuctDimn
        self.numOuterSticks = numOuterSticks
        self.stickWidth = stickWidth
        self.sections = sections
    }
}
