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
        
        case both // non-directed flow
        case inner
        case outer
    }
    
    var discs:[DiscModel] = []
    
    let numAxialColumns:Int
    let blockWidth:Double
    
    var PVMatrix:PCH_SparseMatrix? = nil
    var NodeTemps:[Double] = []
    
    var inletLoc:InletLocation
    
    init(numAxialColumns:Int, blockWidth:Double, inletLoc:InletLocation = .inner, discs:[DiscModel] = [])
    {
        self.numAxialColumns = numAxialColumns
        self.blockWidth = blockWidth
        self.discs = discs
        self.inletLoc = inletLoc
    }
    
    /// Convenience function to set up a disc section. The calling routine should go in and set the eddy-loss percentages manually after getting back an array created this way.
    static func CreateDiscArray(numDiscs:Int, baseDisc:DiscModel) -> [DiscModel]
    {
        let result = [DiscModel](repeating:baseDisc, count: numDiscs)
        
        return result;
    }
    
    /// Initialize the node temperature array, with tIn as the inlet temp and deltaT as the rise through the section
    func InitializeNodeTemps(tIn:Double, deltaT:Double)
    {
        guard self.discs.count > 0 else
        {
            DLog("No discs have been defined! Aborting!")
            return
        }
        
        let numDiscs = self.discs.count
        let deltaTperDisc = deltaT / Double(numDiscs)
        var nTemp = tIn
        
        self.NodeTemps = [Double](repeating: tIn, count: 2 * numDiscs + 3)
        
        for i in 0...numDiscs + 1
        {
            nTemp += deltaTperDisc
            self.NodeTemps[2*i-1] = nTemp
            self.NodeTemps[2*i] = nTemp + 0.5 * deltaTperDisc
        }
    }
    
    
    /// Create and populate a sparse matrix to calculate the pressures and velocities, using whatever data we have stored in the instance. If the matrix was created, return true, otherwise false. If no discs have been modeled, the routine does nothing and returns false
    func CreatePVmatrix(pIn:Double, vIn:Double) -> Bool
    {
        if self.PVMatrix != nil
        {
            DLog("PV matrix already exists - overwriting!")
        }
        
        guard self.discs.count > 0 else
        {
            DLog("No discs have been defined! Aborting!")
            return false
        }
        
        let dimension = 5 * discs.count + 4
        
        self.PVMatrix = PCH_SparseMatrix(type: .double, rows: dimension, cols: dimension)
        
        return self.SetupPVMatrix(pIn: pIn, vIn: vIn)
    }
    
    func SetupPVMatrix(pIn:Double, vIn:Double) -> Bool
    {
        guard let pvm = self.PVMatrix else
        {
            DLog("PV matrix does not exist - aborting!")
            return false
        }
        
        guard self.discs.count > 0 else
        {
            DLog("No discs have been defined! Aborting!")
            return false
        }
        
        let n = self.discs.count
        let dimension = 5 * discs.count + 4
        
        var B = [Double](repeating: 0.0, count: dimension)
        
        // We define columns 1(index 0) through 2n+2 (index 2n+1) to be P1 through P2n+2.
        // Column 2n+3 (index 2n+2) through 5n+4 (index 5n+3) are used for velocities (v1 to v3n+2)
        
        // offsets into the matrix for the different parts (one less than the path and node numbers because we're using 0-based indexing)
        let pOffset = -1
        let vOffset = 2 * n + 1
        
        var currentDisc = self.discs[0]
        
        // Initialize p1 (using pIn as P0 and vIn as v0)
        var rowIndex = pOffset + 1
        pvm[rowIndex, rowIndex] = 1.0
        B[rowIndex] = pIn - PressureChangeUsingKandD(currentDisc.kInner, currentDisc.Dinner, OilViscosity(self.NodeTemps[0]), currentDisc.verticalPathLength, vIn)
        
        for i in 1..<n
        {
            // solve for P(2i-1) - P(2i) and stuff it into row 2i
            rowIndex = pOffset + 2*i
            
            pvm[rowIndex, pOffset + 2*i] = -1.0
            pvm[rowIndex, pOffset + 2*i-1] = 1.0
            
            // v(3i-1) is unknown, so we pass 1 as the velocity in the call to PressureChangeUsing... which will yield the required coefficient
            var vCoeff = PressureChangeUsingKandD(currentDisc.kBelow, currentDisc.Dbelow, OilViscosity((self.NodeTemps[2*i] + self.NodeTemps[2*i-1]) / 2.0), currentDisc.horizontalPathLength, 1.0)
            // the velocity moves from the right side of the equation to the left, so we take the negative of the coefficient
            pvm[rowIndex, vOffset + 3*i-1] = -vCoeff
            
            // advance to the next disc in the section
            currentDisc = self.discs[i]
        }
        
        return true
    }
    

}
