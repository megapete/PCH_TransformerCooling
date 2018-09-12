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
        
    }
    

}
