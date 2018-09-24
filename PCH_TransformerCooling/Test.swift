//
//  Test.swift
//  PCH_TransformerCooling
//
//  Created by Peter Huber on 2018-09-19.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

import Foundation

func RunThermalTest()
{
    let metricConv = 25.4 / 1000.0
    
    let lvDisc = DiscModel(innerDiameter: 22.676 * metricConv, radialBuild: 1.874 * metricConv, height: 0.3746 * metricConv, paperThickness: 0.018 * metricConv, belowGap: 0.15 * metricConv, aboveGap: 0.15 * metricConv, numColumns: 22, resistanceAt20C: 0.42426 / 98, eddyPU: 0.02, aboveSpaceFactor: 0.572, belowSpaceFactor: 0.572, innerSpaceFactor: 0.537, outerSpaceFactor: 0.603, innerGap: 0.25 * metricConv, outerGap: 0.25 * metricConv, innerSticks: 44, outerSticks: 44)
    
    var lvDiscArray = SectionModel.CreateDiscArray(numDiscs: 33, baseDisc: lvDisc)
    
    let lvBottomSection = SectionModel(numAxialColumns: 22, blockWidth: 1.5 * metricConv, inletLoc: .inner, discs: lvDiscArray)
    lvBottomSection.InitializeNodeTemps(tIn: 20.0, deltaT: 1.5)
    
    let lvMiddleSection = SectionModel(numAxialColumns: 22, blockWidth: 1.5 * metricConv, inletLoc: .outer, discs: lvDiscArray)
    lvDiscArray.removeLast()
    lvMiddleSection.InitializeNodeTemps(tIn: 21.5, deltaT: 1.5)
    
    lvDiscArray.last!.eddyPU = 0.0865
    let lvTopSection = SectionModel(numAxialColumns: 22, blockWidth: 1.5 * metricConv, inletLoc: .inner, discs: lvDiscArray)
    lvTopSection.InitializeNodeTemps(tIn: 23, deltaT: 2.0)
    
    // TODO: Fix eddy losses "per disc"
    
    let lvCoil = CoilModel(amps: 113.6, coilID: 22.676 * metricConv, numInnerSticks: 44, numOuterSticks: 44, sections:[lvBottomSection, lvMiddleSection, lvTopSection])
    
    let height = lvCoil.Height()
    var loss = lvCoil.Loss()
    
    // lvCoil.p0 = PressureChangeInCoil(FLUID_DENSITY_OF_OIL, height, 2.5)
    // lvCoil.v0 = InitialOilVelocity(loss, lvDisc.Ainner, 5.0)
    
    var tBot = 20.0
    var tAmb = 20.0
    var result = lvCoil.SimulateThermalWithTemps(tBottom: tBot, tTop: tBot + 0.0, coolingOffset: 0.381, radHeight: 2.3)
    
    let topDisc = lvDiscArray.last!
    DLog("LV loss: \(loss) watts; Top oil temp: \(result.T)°C; Top disc temp: \(topDisc.temperature)°C")
    
    
    
    
    while true // result.T < 70.0
    {
        // tBot += 1.0
        result = lvCoil.SimulateThermalWithTemps(tBottom: tBot, tTop: result.T, coolingOffset: 0.381, radHeight: 2.3)
        loss = lvCoil.Loss()
        DLog("LV loss: \(loss) watts; Top oil temp: \(result.T)°C; Top disc temp: \(topDisc.temperature)°C")
    }
    
}
