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
    var Tmatrix:PCH_SparseMatrix? = nil
    var nodeTemps:[Double] = []
    var nodePressures:[Double] = []
    var pathVelocities:[Double] = []
    
    var inletLoc:InletLocation
    
    var desc:String = ""
    
    init(numAxialColumns:Int, blockWidth:Double, inletLoc:InletLocation = .inner, discs:[DiscModel] = [])
    {
        self.numAxialColumns = numAxialColumns
        self.blockWidth = blockWidth
        self.discs = discs
        self.inletLoc = inletLoc
    }
    
    // The volumetric flow out the top of the coil section
    func Qout() -> Double
    {
        guard self.discs.count > 0 else
        {
            DLog("No discs have been defined! Aborting!")
            return Double.greatestFiniteMagnitude
        }
        
        guard self.pathVelocities.count > 0 else
        {
            DLog("The solution matrix systems must be solved at least once to get the flow")
            return Double.greatestFiniteMagnitude
        }
        
        let area = (self.inletLoc == .outer ? self.discs.last!.Aouter : self.discs.last!.Ainner)
        
        return pathVelocities.last! * area
    }
    
    /// Convenience function to set up a disc section. The calling routine should go in and set the eddy-loss percentages manually after getting back an array created this way.
    static func CreateDiscArray(numDiscs:Int, baseDisc:DiscModel) -> [DiscModel]
    {
        let result = [DiscModel](repeating:baseDisc, count: numDiscs)
        
        return result;
    }
    
    /// The total loss of the discs in the section at the given amps with the current;y stored disc temperatures
    func TotalLoss(amps:Double) -> Double
    {
        var result:Double = 0.0
        
        for nextDisc in self.discs
        {
            result += nextDisc.Loss(amps: amps)
        }
        
        return result
    }
    
    /// The overall height of the section
    func Height() -> Double
    {
        guard self.discs.count > 0 else
        {
            return 0.0
        }
        
        var result = 0.0
        
        for nextDisc in self.discs
        {
            result += (nextDisc.belowGap + nextDisc.dims.h)
        }
        
        result += self.discs.last!.aboveGap
        
        return result
    }
    
    /// Initialize the node temperature array, with tIn as the inlet temp and deltaT as the rise through the section. Return the last temperature (at the top of the section)
    func InitializeNodeTemps(tIn:Double, deltaT:Double) -> Double
    {
        guard self.discs.count > 0 else
        {
            DLog("No discs have been defined! Aborting!")
            return -Double.greatestFiniteMagnitude
        }
        
        let n = self.discs.count
        let deltaTperDisc = deltaT / Double(n+1)
        var nTemp = tIn
        
        self.nodeTemps = [Double](repeating: tIn, count: 2 * n + 3)
        
        for i in 1...n + 1
        {
            nTemp += deltaTperDisc
            self.nodeTemps[2*i-1] = nTemp
            self.nodeTemps[2*i] = nTemp + 0.5 * deltaTperDisc
        }
        
        return self.nodeTemps[2*n+2]
    }
    
    /// Create and populate a sparse matrix to calculate the node temperatures. If the matrix was created then solve it, otheriwse return false. If no discs have been modeled, the routine does nothing and returns false.
    func CreateAndSolveTmatrix(amps:Double, tIn: inout Double) -> Bool
    {
        if self.Tmatrix != nil
        {
            DLog("T matrix already exists - overwriting!")
        }
        
        guard self.discs.count > 0 else
        {
            DLog("No discs have been defined! Aborting!")
            return false
        }
        
        // per BB2E p515, we only need 3n+1 delta-T equations plus 2n+2 energy balance equations
        let dimension = 5 * discs.count + 3
        
        self.Tmatrix = PCH_SparseMatrix(type: .double, rows: dimension, cols: dimension)
        
        return self.SetupAndSolveTmatrix(amps: amps, tIn: &tIn)
    }
    
    func SetupAndSolveTmatrix(amps:Double, tIn: inout Double) -> Bool
    {
        self.nodeTemps[0] = tIn
        
        let n = self.discs.count
        let dimension = 5 * n + 3
        
        var old_tOut = 0.0
        var tOut = self.nodeTemps[2*n+2]
        
        guard let T = self.Tmatrix else
        {
            DLog("Temperature matrix was not created - aborting!")
            return false
        }
        
        var outputString = ""
        
        repeat {
            
            old_tOut = tOut
            
            // update all the disc temperatures using the current surrounding node temps, path velocities, and amps through the disc
            for i in 1...n
            {
                self.discs[i-1].UpdateTemperature(amps: amps, inletLocation: self.inletLoc, T1: self.nodeTemps[2*i-1], T2: self.nodeTemps[2*i], T3: self.nodeTemps[2*i+1], T4: self.nodeTemps[2*i+2], v12: self.pathVelocities[3*i-1], v34: self.pathVelocities[3*i+2], v13: self.pathVelocities[3*i+1], v24: self.pathVelocities[3*i])
            }
            
            // constant that turns up a lot
            let cp = SPECIFIC_HEAT_OF_OIL * FLUID_DENSITY_OF_OIL_40
            
            var B = [Double](repeating: 0.0, count: dimension)
            
            T.ClearEntries()
            
            // We'll adopt the numbering system that I used in the old program. The final temperature stored is at node 2n+2, which translates into index (row) 2n+1 in the matrix solutio. We don't store T0, so we define the nodal offset as -1 (so that T1 gets stored at row 0). The first delta-T we store is on path 2, which we will want to store at row 2n+2. We therefore use an offset of 2n for the delta-T rows.
            let nodalToffset = -1
            let deltaToffset = 2 * n
            
            // HORIZONTAL Ducts
            
            // Do the duct under the first disc
            var currentDisc = self.discs[0]
            var rowIndex = deltaToffset + 2
            var Tci = currentDisc.temperature
            var hAc0 = currentDisc.hBelow * currentDisc.AcBelow
            // var Ac0 = currentDisc.AcAbove
            var A0i = currentDisc.Abelow
            
            B[rowIndex] = hAc0 * Tci
            
            T[rowIndex, rowIndex] = cp * A0i * self.pathVelocities[2] + hAc0 * 0.5
            T[rowIndex, nodalToffset + 1] = hAc0
            
            // Do all the horizontal delta-T's under the discs (paths 3i-1) in the main field (ie: from disc 2 to disc n)
            for i in 2...n
            {
                currentDisc = self.discs[i-1]
                
                // put this equation into the 3i-1 row
                rowIndex = deltaToffset + 3*i-1
                
                let TciPrev = Tci
                Tci = currentDisc.temperature
                
                hAc0 = currentDisc.hBelow * currentDisc.AcBelow
                A0i = currentDisc.Abelow
                
                B[rowIndex] = hAc0 * (Tci + TciPrev)
                
                T[rowIndex, rowIndex] = cp * A0i * self.pathVelocities[3*i-1] + hAc0
                T[rowIndex, nodalToffset + 2*i-1] = 2.0 * hAc0
            }
            
            // Now the horizontal duct above the final disc
            currentDisc = self.discs[n-1]
            rowIndex = deltaToffset + 3*n+2
            Tci = currentDisc.temperature
            hAc0 = currentDisc.hAbove * currentDisc.AcAbove
            A0i = currentDisc.Aabove
            
            B[rowIndex] = hAc0 * Tci
            
            T[rowIndex, rowIndex] = cp * A0i * self.pathVelocities[3*n+2] + hAc0 * 0.5
            T[rowIndex, nodalToffset + 2*n+1] = hAc0
            
            // VERTICAL Ducts
            
            // Incoming temp, which was set on entry to this routine
            T[0,0] = 1.0
            B[0] = self.nodeTemps[0]
            
            // Two ducts for each disc
            for i in 1...n
            {
                currentDisc = self.discs[i-1]
                Tci = currentDisc.temperature
                
                // variables depend on the inlet location. Default to inner
                var hAc1 = currentDisc.hInner * currentDisc.AcInner
                var hAc2 = currentDisc.hOuter * currentDisc.AcOuter
                var A1 = currentDisc.Ainner
                var A2 = currentDisc.Aouter
                
                if self.inletLoc == .outer
                {
                    let swap_hAc = hAc2
                    hAc2 = hAc1
                    hAc1 = swap_hAc
                    let swap_A = A2
                    A2 = A1
                    A1 = swap_A
                }
                
                // A1 duct
                rowIndex = deltaToffset + 3*i+1
                B[rowIndex] = hAc1 * Tci
                T[rowIndex, rowIndex] = cp * A1 * self.pathVelocities[3*i+1] + hAc1 * 0.5
                T[rowIndex, nodalToffset + 2*i-1] = hAc1
                
                // A2 duct
                rowIndex = deltaToffset + 3*i
                B[rowIndex] = hAc2 * Tci
                T[rowIndex, rowIndex] = cp * A2 * self.pathVelocities[3*i] + hAc2 * 0.5
                T[rowIndex, nodalToffset + 2*i] = hAc2
            }
            
            // and now energy-balance equations
            // let A1 = (self.inletLoc == .inner ? self.discs[0].Ainner : self.discs[0].Aouter)
            let A2 = (self.inletLoc == .outer ? self.discs[0].Ainner : self.discs[0].Aouter)
            
            // Start with temperature node 2 (temperature node 1 is known and was set above)
            rowIndex = nodalToffset + 2
            A0i = self.discs[0].Abelow
            
            T[rowIndex, rowIndex] = -A2 * self.pathVelocities[3]
            T[rowIndex, nodalToffset + 1] = A0i * self.pathVelocities[2]
            T[rowIndex, deltaToffset + 2] = A0i * self.pathVelocities[2]
            
            // Now the main field
            for i in 2...n
            {
                // start with the simple (and obvious) equation and store it in the T(2i-1) row
                rowIndex = nodalToffset + 2*i-1
                T[rowIndex, rowIndex] = 1.0
                T[rowIndex, nodalToffset + 2*i-3] = -1.0
                T[rowIndex, deltaToffset + 3*i-2] = -1.0
                
                // now the more complicated equation, stored in T(2i)
                rowIndex = nodalToffset + 2*i
                let A0iV = self.discs[i-1].Abelow * self.pathVelocities[3*i-1]
                let A2V = A2 * self.pathVelocities[3*i-3]
                
                T[rowIndex, rowIndex] = -A2 * self.pathVelocities[3*i]
                T[rowIndex, nodalToffset + 2*i-1] = A0iV
                T[rowIndex, deltaToffset + 3*i-1] = A0iV
                T[rowIndex, nodalToffset + 2*i-2] = A2V
                T[rowIndex, deltaToffset + 3*i-3] = A2V
            }
            
            // Now the final "inner" node (actually, the "A1" node)
            rowIndex = nodalToffset + 2*n+1
            T[rowIndex, rowIndex] = 1.0
            T[rowIndex, nodalToffset + 2*n-1] = -1.0
            T[rowIndex, deltaToffset + 3*n+1] = -1.0
            
            // and the final "outer" node ("A2" node)
            rowIndex = nodalToffset + 2*n+2
            let A0iV = self.discs.last!.Aabove * self.pathVelocities[3*n+2]
            let A2V = A2 * self.pathVelocities[3*n]
            
            // don't forget that we renamed V(3n+3) as V(1)
            T[rowIndex, rowIndex] = -A2 * self.pathVelocities[1]
            T[rowIndex, nodalToffset + 2*n+1] = A0iV
            T[rowIndex, deltaToffset + 3*n+2] = A0iV
            T[rowIndex, nodalToffset + 2*n] = A2V
            T[rowIndex, deltaToffset + 3*n] = A2V
            
            // T.OutputAsCSV(url: theURL)
            
            // That's it, solve the freakin' thing
            
            let X = T.SolveWithVector(Bv: B)
            
            for i in 1...2*n+2
            {
                let nextTemp = X[nodalToffset + i]
                
                if nextTemp.isNaN
                {
                    ALog("Got a NaN at temperature index: \(i)")
                }
                
                self.nodeTemps[i] = nextTemp
                outputString.append("\(self.nodeTemps[i])\n")
            }
            
            tOut = self.nodeTemps[2*n+2]
            
        } while fabs(old_tOut - tOut) > 0.1
        
        // debugging
        // let docDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        // let theURL = docDir.appendingPathComponent("NodeTemps_\(self.desc).txt")
        // DLog("URL: \(theURL.absoluteString)")
        
        /*
        do
        {
            try outputString.write(to: theURL, atomically: true, encoding: .utf16)
            
        } catch {
            
            DLog("Write error: \(error.localizedDescription)")
        }
        */
        
        tIn = tOut
        
        return true
    }
    
    
    /// Create and populate a sparse matrix to calculate the pressures and velocities, using whatever data we have stored in the instance. If the matrix was created then solve the system, otherwise return false. If no discs have been modeled, the routine does nothing and returns false
    func CreateAndSolvePVmatrix(pIn: inout Double, vIn: inout Double) -> Bool
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
        
        return self.SetupAndSolvePVMatrix(pIn: &pIn, vIn: &vIn)
    }
    
    /// Update the coefficients and solve the PV matrix system
    func SetupAndSolvePVMatrix(pIn: inout Double, vIn: inout Double) -> Bool
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
        
        // if the matrix has been used before, clear its entries
        if pvm.NumEntries() > 0
        {
            pvm.ClearEntries()
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
        B[rowIndex] = pIn - PressureChangeUsingKandD(currentDisc.kInner, currentDisc.Dinner, OilViscosity(self.nodeTemps[0]), currentDisc.verticalPathLength, vIn)
        
        // We need to be careful with filling the PV matrix. We need to remember that for an arbitrary disc i, the 2i+1 and 2i+2 nodes are the 2i and 2i-1 nodes AFTER i has been incremented. If we just blindly set the matrix row to all 4 nodes around a disc, then the numbers associated those two nodes will be clobbered by the next disc. For that reason, we only solve for P(2i) and P(2i+1) for each disc. We also note that the path 3i+2 is the 3i-1 path after incrementing i, so we won't do that one either. We WILL do the path 3i, and save the equation in THAT row. However, after doing the final disc, we DO need to solve for the final horizontal path (3n+2).
        for i in 1...n
        {
            // advance to the next disc in the section
            currentDisc = self.discs[i-1]
            
            // solve for P(2i-1) - P(2i) and stuff it into row 2i
            rowIndex = pOffset + 2*i
            
            pvm[rowIndex, pOffset + 2*i] = -1.0
            pvm[rowIndex, pOffset + 2*i-1] = 1.0
            
            // v(3i-1) is unknown, so we pass 1 as the velocity in the call to PressureChangeUsing... which will yield the required coefficient
            var vCoeff = PressureChangeUsingKandD(currentDisc.kBelow, currentDisc.Dbelow, OilViscosity((self.nodeTemps[2*i] + self.nodeTemps[2*i-1]) / 2.0), currentDisc.horizontalPathLength, 1.0)
            // the velocity moves from the right side of the equation to the left, so we take the negative of the coefficient
            pvm[rowIndex, vOffset + 3*i-1] = -vCoeff
            
            // now we'll solve for P(2i-1) - P(2i+1) and put it in row 2i+1
            rowIndex = pOffset + 2*i+1
            
            pvm[rowIndex, pOffset + 2*i+1] = -1.0;
            pvm[rowIndex, pOffset + 2*i-1] = 1.0
            
            // The other two paths we solve for are the vertical ones. That means that both K and D depend on whether the oil is coming in on the inner or outer duct.
            var D = (self.inletLoc == .inner ? currentDisc.Dinner : currentDisc.Douter)
            var K = (self.inletLoc == .inner ? currentDisc.kInner : currentDisc.kOuter)
            
            vCoeff = PressureChangeUsingKandD(K, D, OilViscosity((self.nodeTemps[2*i-1] + self.nodeTemps[2*i+1]) / 2.0), currentDisc.verticalPathLength, 1.0)
            pvm[rowIndex, vOffset + 3*i+1] = -vCoeff
            
            // we now solve for P(2i) - P(2i+2) and stuff it into row v3i (ie: vOffset + 3i)
            rowIndex = vOffset + 3*i
            
            pvm[rowIndex, pOffset + 2*i+2] = -1.0
            pvm[rowIndex, pOffset + 2*i] = 1.0
            
            D = (self.inletLoc == .outer ? currentDisc.Dinner : currentDisc.Douter)
            K = (self.inletLoc == .outer ? currentDisc.kInner : currentDisc.kOuter)
            
            vCoeff = PressureChangeUsingKandD(K, D, OilViscosity((self.nodeTemps[2*i] + self.nodeTemps[2*i+2]) / 2.0), currentDisc.verticalPathLength, 1.0)
            pvm[rowIndex, vOffset + 3*i] = -vCoeff
        }
        
        // Now do the last path, P(2n+1) - P(2n+2) and store it in row 2n+2
        rowIndex = pOffset + 2*n+2
        pvm[rowIndex, pOffset + 2*n+2] = -1.0
        pvm[rowIndex, pOffset + 2*n+1] = 1.0
        
        let vCoeff = PressureChangeUsingKandD(currentDisc.kAbove, currentDisc.Dabove, OilViscosity((self.nodeTemps[2*n+1] + self.nodeTemps[2*n+2]) / 2.0), currentDisc.horizontalPathLength, 1.0)
        pvm[rowIndex, vOffset + 3*n+2] = -vCoeff
        
        // Now we'll take care of the missing velocity equations. The only ones that are done are the 3i velocities. We need to do 3i-1 and 3i+1 for each disc. The first and last discs need special attention.
        
        currentDisc = self.discs[0]
        // First set A1 and A2 according to the inlet side
        var A1 = (self.inletLoc == .inner ? currentDisc.Ainner : currentDisc.Aouter)
        var A2 = (self.inletLoc == .inner ? currentDisc.Aouter : currentDisc.Ainner)
        
        // Handle first disc, BB2E p512, eq:15.10
        // save into v4 row
        rowIndex = vOffset + 4
        pvm[rowIndex, vOffset + 4] = A1
        pvm[rowIndex, vOffset + 2] = currentDisc.Abelow
        B[rowIndex] = A1 * vIn
        
        // BB2E p512, eq:15.11
        // save into v2 row
        rowIndex = vOffset + 2
        pvm[rowIndex, vOffset + 2] = currentDisc.Abelow
        pvm[rowIndex, vOffset + 3] = -A2
        
        // Now set the last disc
        currentDisc = self.discs.last!
        A1 = (self.inletLoc == .inner ? currentDisc.Ainner : currentDisc.Aouter)
        A2 = (self.inletLoc == .inner ? currentDisc.Aouter : currentDisc.Ainner)
        
        // BB2E p512, eq:15.12
        // save into v(3n+2)
        rowIndex = vOffset + 3*n+2
        pvm[rowIndex, vOffset + 3*n+1] = -A1
        pvm[rowIndex, vOffset + 3*n+2] = currentDisc.Aabove
        
        // BB2E p512, eq:15.13
        // into v1
        rowIndex = vOffset + 1
        pvm[rowIndex, vOffset + 1] = A2
        pvm[rowIndex, vOffset + 3*n] = -A2
        pvm[rowIndex, vOffset + 3*n+2] = -currentDisc.Aabove
        
        for i in 2...n
        {
            currentDisc = self.discs[i-1]
            A1 = (self.inletLoc == .inner ? currentDisc.Ainner : currentDisc.Aouter)
            A2 = (self.inletLoc == .inner ? currentDisc.Aouter : currentDisc.Ainner)
            
            // BB2E p512, eq:15.8
            // into v(3i+1)
            rowIndex = vOffset + 3*i+1
            pvm[rowIndex, vOffset + 3*i+1] = A1
            pvm[rowIndex, vOffset + 3*i-1] = currentDisc.Abelow
            pvm[rowIndex, vOffset + 3*i-2] = -A1
            
            // BB2E p512, eq:15.9
            // into v(3i-1)
            rowIndex = vOffset + 3*i-1
            pvm[rowIndex, vOffset + 3*i-1] = currentDisc.Abelow
            pvm[rowIndex, vOffset + 3*i-3] = A2
            pvm[rowIndex, vOffset + 3*i] = -A2
        }
        
        // debugging
        // let docDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        // let theURL = docDir.appendingPathComponent("PV_Matrix.txt")
        // DLog("URL: \(theURL.absoluteString)")
        
        // pvm.OutputAsCSV(url: theURL)
        
        let X = pvm.SolveWithVector(Bv: B)
        
        guard X.count > 0 else
        {
            DLog("Could not solve system")
            return false
        }
        
        self.nodePressures = [pIn]
        self.pathVelocities = [vIn]
        
        for i in 0..<5*n+4
        {
            if i < 2*n+2
            {
                self.nodePressures.append(X[i])
            }
            else
            {
                // DLog("X[\(i)] = \(X[i])")
                self.pathVelocities.append(X[i])
            }
        }
        
        pIn = X[pOffset + 2*n+2]
        vIn = X[vOffset + 1]
        
        return true
    }
    

}
