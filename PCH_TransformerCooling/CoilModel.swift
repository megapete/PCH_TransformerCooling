//
//  CoilModel.swift
//  PCH_TransformerCooling
//
//  Created by PeterCoolAssHuber on 2018-09-11.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

import Cocoa

let pressureRelaxationFactor = 0.75
let velocityRelaxationFactor = 0.75

class CoilModel: NSObject {
    
    let usesOilFlowWashers:Bool
    
    let innerDuctDimn:Double
    let numInnerSticks:Int
    let outerDuctDimn:Double
    let numOuterSticks:Int
    
    let stickWidth:Double
    
    let coilID:Double
    
    let amps:Double
    
    var p0:Double = 0.0
    var v0:Double = 0.0
    
    var tBottom = 20.0
    var tTop = 25.0
    
    var sections:[SectionModel] = []
    
    init(amps:Double, coilID:Double, usesOilFlowWashers:Bool = true, innerDuctDimn:Double = 0.00635, numInnerSticks:Int, outerDuctDimn:Double = 0.00635, numOuterSticks:Int, stickWidth:Double = 0.01905, sections:[SectionModel] = [], initialTbottom:Double = 20.0, initialTtop:Double = 25.0)
    {
        self.amps = amps
        self.coilID = coilID
        self.usesOilFlowWashers = usesOilFlowWashers
        self.innerDuctDimn = innerDuctDimn
        self.numInnerSticks = numInnerSticks
        self.outerDuctDimn = outerDuctDimn
        self.numOuterSticks = numOuterSticks
        self.stickWidth = stickWidth
        self.sections = sections
        self.tTop = initialTtop
        self.tBottom = initialTbottom
    }
    
    // The volumetric flow out of the coil, based on the oil velocity out of the topmost coil section
    func Qout() -> Double
    {
        guard self.sections.count > 0 else
        {
            DLog("No sections have been defined")
            return -Double.greatestFiniteMagnitude
        }
        
        return self.sections.last!.Qout()
    }
    
    /// This is the function that should be called to calculate the thermal performance of the coil. It returns the oil temperature exiting the coil at the top and the volumetric flow.
    func SimulateThermalWithTemps(tBottom:Double, tTop:Double) -> (T:Double, Q:Double)
    {
        guard self.sections.count > 0 else
        {
            DLog("No sections have been defined")
            return (-Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude)
        }
        
        self.InitializeInputParameters(tBottom: tBottom, tTop: tTop)
        
        var pIn = self.p0
        var vIn = self.v0
        var tBot = self.tBottom
        
        for nextSection in self.sections
        {
            if nextSection.PVMatrix == nil
            {
                guard nextSection.CreateAndSolvePVmatrix(pIn: &pIn, vIn: &vIn) else
                {
                    DLog("PV calculation falied")
                    return (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)
                }
            }
            else
            {
                guard nextSection.SetupAndSolvePVMatrix(pIn: &pIn, vIn: &vIn) else
                {
                    DLog("PV calculation falied")
                    return (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)
                }
            }
            
            if nextSection.Tmatrix == nil
            {
                guard nextSection.CreateAndSolveTmatrix(amps: self.amps, tIn: &tBot) else
                {
                    DLog("Temp calculation falied")
                    return (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)
                }
            }
            else
            {
                guard nextSection.SetupAndSolveTmatrix(amps: self.amps, tIn: &tBot) else
                {
                    DLog("Temp calculation falied")
                    return (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)
                }
            }
        }
        
        return (self.Qout(), tBot)
    }
    
    func InitializeInputParameters(tBottom:Double, tTop:Double)
    {
        guard sections.count > 0 else
        {
            DLog("No sections have been defined")
            
            return
        }
        
        guard self.sections[0].inletLoc != .both else
        {
            DLog("Non-directed flow is not yet implemented")
            return
        }
        
        guard self.sections[0].discs.count != 0 else
        {
            DLog("No discs have been defined")
            return
        }
        
        let bottomMostDisc = self.sections[0].discs[0]
        
        let inletArea = (self.sections[0].inletLoc == .inner ? bottomMostDisc.Ainner : bottomMostDisc.Aouter)
        
        var deltaT = tTop - tBottom
        
        if deltaT == 0.0
        {
            DLog("Top oil must be greater than bottom oil. Setting to a difference of 1.0")
            deltaT = 1.0
        }
        else
        {
            self.tTop = tTop
            self.tBottom = tBottom
        }
        
        let newPfraction = 1.0 - pressureRelaxationFactor
        let newVfraction = 1.0 - velocityRelaxationFactor
        
        self.p0 = pressureRelaxationFactor * self.p0 + newPfraction * PressureChangeInCoil(FLUID_DENSITY_OF_OIL, self.Height(), deltaT)
        self.v0 = velocityRelaxationFactor * self.v0 + newVfraction * InitialOilVelocity(self.Loss(), inletArea, deltaT)
    }
    
    /// Get the overall loss of the coil
    func Loss() -> Double
    {
        var result = 0.0
        
        for nextSection in self.sections
        {
            result += nextSection.TotalLoss(amps: self.amps)
        }
        
        return result
    }
    
    /// Get the overall height of the coil
    func Height() -> Double
    {
        var result = 0.0
        
        for nextSection in self.sections
        {
            result += nextSection.Height()
        }
        
        return result
    }
    
    /// Convenience routine to quickly create coils by copying a given section. For directed-flow coils, the calling program can specify whether the inlet locations should alternate from section to section. Section 0 is considered to be the bottom-most section.
    static func CreateSections(numSections:Int, baseSect:SectionModel, alternateInlets:Bool = true) -> [SectionModel]
    {
        let result = [SectionModel](repeating: baseSect, count: numSections)
        
        if alternateInlets && baseSect.inletLoc != .both
        {
            let newInletLoc:SectionModel.InletLocation = (baseSect.inletLoc == .inner ? .outer : .inner)
            
            var index = 1;
            while index < result.count
            {
                result[index].inletLoc = newInletLoc
                
                index += 2
            }
        }
        
        return result
    }
}
