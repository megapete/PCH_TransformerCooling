//
//  BluebookThermalFunctions.c
//  PCH_TransformerCooling
//
//  Created by Peter Huber on 2018-09-10.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

#include "BluebookThermalFunctions.h"

/// General function to calculate hydraulic diameter for an arbitrary shape, given the cross-secitonal area and the wetted perimeter
double HydraulicDiameter(double xSect, double wPerimeter)
{
    return 4.0 * xSect / wPerimeter;
}

/// Specific function to calculate the hydraulic diameter of a rectangular duct
double HydraulicDiameterOfRect(double w, double h)
{
    return HydraulicDiameter(w * h, 2.0 * (w + h));
}

/// The Reynolds number (Bluebook 2E, page 510, formula 15.2)
double ReynoldsNumber(double fDensity, double fVelocity, double hydraulicDiameter, double fViscosity)
{
    return fDensity * fVelocity * hydraulicDiameter / fViscosity;
}

/// Friction coefficient for laminar flows in circular ducts (BB2E, p510)
double FrictionCoefficientCircularDuct(double reynoldsNumber)
{
    return 64.0 / reynoldsNumber;
}

/// Friction coefficient for laminar flows in rectangular ducts ((BB2E, p510, f:15.3)
double FrictionCoefficientRectangularDuct(double w, double h, double reynoldsNumber)
{
    double a = (w < h ? w : h);
    double b = (w < h ? h : w);
    
    double K = 56.91 + 40.31 * (exp(-3.5 * a / b) - 0.0302); // f:15.4
    
    return K / reynoldsNumber;
}

/// Pressure change in a rectangular duct from point 1 to point 2 (BB2E, p510, f:15.5)
double PressureChangeRectangularDuct(double w, double h, double fViscosity, double pathLength, double fVelocity)
{
    double a = (w < h ? w : h);
    double b = (w < h ? h : w);
    
    double K = 56.91 + 40.31 * (exp(-3.5 * a / b) - 0.0302); // f:15.4
    double D = HydraulicDiameterOfRect(w, h);
    
    return 0.5 * fViscosity * K * pathLength * fVelocity / (D * D);
}

/// Pressure change in a coil (used to come up with the pressure at the bottom of the coil - BB2E, p513, eq:15.16) as caused by the temperature difference between the top and bottom.
double PressureChangeInCoil(double fDensity, double coilHt, double deltaT)
{
    double B = 6.8E-4;
    double g = 9.80665;
    
    return B * fDensity * g * coilHt * deltaT;
}

/// Oil viscosity (BB2E, p511, f:15.6)
double OilViscosity(double tempInC)
{
    double cubedValue = (tempInC + 50.0) * (tempInC + 50.0) * (tempInC + 50.0);
    
    return 6900.0 / cubedValue;
}








