//
//  DiscModel.swift
//  PCH_TransformerCooling
//
//  Created by PeterCoolAssHuber on 2018-09-11.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

import Cocoa

class DiscModel: NSObject {
    
    // Things that don't change
    let dims:(ID:Double, rb:Double, h:Double)
    let paperCover:Double
    
    let belowGap:Double
    let aboveGap:Double
    
    // the per-unit exposed surface / total surface
    let aboveGapSpaceFactor:Double
    let belowGapSpaceFactor:Double
    
    let resistance20:Double
    let eddyPU:Double
    
    // Things that need to be calculated in the initializer
    let Dinner:Double
    let Douter:Double
    
    let Dabove:Double
    let Dbelow:Double
    
    let Ainner:Double
    let Aouter:Double
    let Aabove:Double
    let Abelow:Double
    
    // Things that need to be calculated every time through
    var temperature:Double = 20.0
    var loss:Double = 0.0
    var hInner:Double = 0.0
    var hOuter:Double = 0.0
    var hAbove:Double = 0.0
    var hBelow:Double = 0.0

    init(innerDiameter:Double, radialBuild:Double, height:Double, paperThickness:Double, belowGap:Double, aboveGap:Double, resistanceAt20C:Double, eddyPU:Double, aboveSpaceFactor:Double, belowSpaceFactor:Double, innerSpaceFactor:Double, outerSpaceFactor:Double, innerGap:Double, outerGap:Double)
    {
        self.dims.ID = innerDiameter
        self.dims.rb = radialBuild
        self.dims.h = height
        self.paperCover = paperThickness
        self.belowGap = belowGap
        self.aboveGap = aboveGap
        self.resistance20 = resistanceAt20C
        self.eddyPU = eddyPU
        self.aboveGapSpaceFactor = aboveSpaceFactor
        self.belowGapSpaceFactor = belowSpaceFactor
        
        // calculate and store the hydraulic diameters for the horizontal ducts
        let lmt = (innerDiameter + radialBuild) * π
        var area = lmt * belowSpaceFactor * belowGap
        var wettedP = (lmt * belowSpaceFactor + belowGap) * 2.0
        self.Dbelow = HydraulicDiameter(area, wettedP)
        area = lmt * aboveSpaceFactor * aboveGap
        wettedP = (lmt * aboveSpaceFactor + aboveGap) * 2.0
        self.Dabove = HydraulicDiameter(area, wettedP)
        
        self.Aabove = lmt * radialBuild * aboveSpaceFactor
        self.Abelow = lmt * radialBuild * belowSpaceFactor
        
        // calculate and store the hydraulic diameters for the vertical ducts
        let lit = (innerDiameter - innerGap) * π
        area = lit * innerSpaceFactor * innerGap
        wettedP = (lit * innerSpaceFactor + innerGap) * 2.0
        self.Dinner = HydraulicDiameter(area, wettedP)
        let lot = (innerDiameter + 2.0 * radialBuild + outerGap) * π
        area = lot * outerSpaceFactor * outerGap
        wettedP = (lot * outerSpaceFactor + outerGap) * 2.0
        self.Douter = HydraulicDiameter(area, wettedP)
        
        self.Ainner = innerDiameter * π * innerSpaceFactor * height
        self.Aouter = (innerDiameter + 2.0 * radialBuild) * π * outerSpaceFactor * height
    }
    
    func Loss(amps:Double, temp:Double) -> Double
    {
        let resistance = self.resistance20 * (234.5 + temp) / (234.5 + 20) * (1.0 + self.eddyPU)
        
        return amps * amps * resistance
    }
    
    func UpdateTemperature(amps:Double, T1:Double, T2:Double, T3:Double, T4:Double, v12:Double, v34:Double, v13:Double, v24:Double)
    {
        
    }
}
