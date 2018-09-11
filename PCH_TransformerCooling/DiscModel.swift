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
    
    // let belowGap:Double
    // let aboveGap:Double
    
    // the per-unit exposed surface / total surface
    // let aboveGapSpaceFactor:Double
    // let belowGapSpaceFactor:Double
    
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
    // var loss:Double = 0.0
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
        // self.belowGap = belowGap
        // self.aboveGap = aboveGap
        self.resistance20 = resistanceAt20C
        self.eddyPU = eddyPU
        // self.aboveGapSpaceFactor = aboveSpaceFactor
        // self.belowGapSpaceFactor = belowSpaceFactor
        
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
    
    func Loss(amps:Double) -> Double
    {
        let resistance = self.resistance20 * (234.5 + self.temperature) / (234.5 + 20) * (1.0 + self.eddyPU)
        
        return amps * amps * resistance
    }
    
    /// Update the temperature of the disc. The subscript numbers for the velocity (12, 34, etc) are the paths as referenced from disc 1. The subscripts for the temperatures are the nodes around disc 1.
    func UpdateTemperature(amps:Double, T1:Double, T2:Double, T3:Double, T4:Double, v12:Double, v34:Double, v13:Double, v24:Double) -> Double
    {
        var oldTemp = self.temperature
        
        let Tbelow = (T1 + T2) / 2.0
        let Tabove = (T3 + T4) / 2.0
        let Tinner = (T1 + T3) / 2.0
        let Touter = (T2 + T4) / 2.0
        
        repeat {
        
            // The losses and the convection coefficient are dependent on the temperature, so we iterate until the calculated temp doesn't change by more than 0.1 degree from one iteration to the next. This is my own decision (ie: it's not in the Bluebook).
            
            oldTemp = self.temperature
        
            let hConv12 = ConvectionCoefficient(self.Dbelow, self.dims.rb, Tbelow, self.temperature - Tbelow, v12)
            self.hBelow = HeatTransferCoefficient(hConv12, self.paperCover, THERMAL_CONDUCTIVITY_OF_PAPER)
            
            let hConv34 = ConvectionCoefficient(self.Dabove, self.dims.rb, Tabove, self.temperature - Tabove, v34)
            self.hAbove = HeatTransferCoefficient(hConv34, self.paperCover, THERMAL_CONDUCTIVITY_OF_PAPER)
            
            let hConv13 = ConvectionCoefficient(self.Dinner, self.dims.h, Tinner, self.temperature - Tinner, v13)
            self.hInner = HeatTransferCoefficient(hConv13, self.paperCover, THERMAL_CONDUCTIVITY_OF_PAPER)
            
            let hConv24 = ConvectionCoefficient(self.Douter, self.dims.h, Touter, self.temperature - Touter, v24)
            self.hOuter = HeatTransferCoefficient(hConv24, self.paperCover, THERMAL_CONDUCTIVITY_OF_PAPER)
            
            self.temperature = (self.Loss(amps: amps) + self.hBelow * self.Abelow * Tbelow + self.hAbove * self.Aabove * Tabove + self.hInner * self.Ainner * Tinner + self.hOuter * self.Aouter * Touter) / (self.hBelow * self.Abelow + self.hAbove * self.Aabove + self.hInner * self.Ainner + self.hOuter * self.Aouter)
            
        
        } while fabs(self.temperature - oldTemp) > 0.1
        
        return self.temperature
        
    }
}









