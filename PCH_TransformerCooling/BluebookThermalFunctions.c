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
    
    //double K = 56.91 + 40.31 * (exp(-3.5 * a / b) - 0.0302); // f:15.4
    
    return K(a, b) / reynoldsNumber;
}

/// Calculate K(a,b) (BB2E, p511, eq:15.4
double K(double a, double b)
{
    double aUse = (a < b ? a : b);
    double bUse = (a < b ? b : a);
    
    return 56.91 + 40.31 * (exp(-3.5 * aUse / bUse) - 0.0302);
}

/// Pressure change in a rectangular duct from point 1 to point 2 (BB2E, p510, f:15.5)
double PressureChangeRectangularDuct(double w, double h, double fViscosity, double pathLength, double fVelocity)
{
    double a = (w < h ? w : h);
    double b = (w < h ? h : w);
    
    // double K = 56.91 + 40.31 * (exp(-3.5 * a / b) - 0.0302); // f:15.4
    double D = HydraulicDiameterOfRect(w, h);
    
    return 0.5 * fViscosity * K(a, b) * pathLength * fVelocity / (D * D);
}

/// Alternate method of calculating pressure change, taking K and D as parameters
double PressureChangeUsingKandD(double K, double D, double fViscosity, double pathLength, double fVelocity)
{
    return 0.5 * fViscosity * K * pathLength * fVelocity / (D * D);
}

/// Pressure change in a coil (used to come up with the pressure at the bottom of the coil - BB2E, p513, eq:15.16) as caused by the temperature difference between the top and bottom.
double PressureChangeInCoil(double fDensity, double coilHt, double deltaT)
{
    double B = VOLUME_COEFFICIENT_OF_THERMAL_EXPANSION_OF_OIL;
    double g = ACCELERATION_DUE_TO_GRAVITY;
    
    return B * fDensity * g * coilHt * deltaT;
}

/// Oil viscosity (BB2E, p511, f:15.6)
double OilViscosity(double tempInC)
{
    double cubedValue = (tempInC + 50.0) * (tempInC + 50.0) * (tempInC + 50.0);
    
    return 6900.0 / cubedValue;
}

/// Initial oil velocity v0 using the given losses (BB2E, p513, eq:15.17)
double InitialOilVelocity(double coilLoss, double inletArea, double deltaT)
{
    double p = FLUID_DENSITY_OF_OIL;
    double c = SPECIFIC_HEAT_OF_OIL;
    
    return coilLoss / (p * c * inletArea * deltaT);
}

/// Prandtl number (BB2E, p514)
double PrandtlNumber(double fViscosity, double fSpecificHeat, double fThermalConductivity)
{
    return fViscosity * fSpecificHeat / fThermalConductivity;
}

/// Convection heat transfer coefficient (BB2E, p514, eq:15.23)
double ConvectionCoefficient(double hydraulicDiameter, double pathLength, double bulkOilTemp, double gradient, double fVelocity)
{
    double p = FLUID_DENSITY_OF_OIL;
    double k = THERMAL_CONDUCTIVITY_OF_OIL;
    double c = SPECIFIC_HEAT_OF_OIL;
    double muBulk = OilViscosity(bulkOilTemp);
    double muSurface = OilViscosity(bulkOilTemp + gradient);
    
    double Re = ReynoldsNumber(p, fVelocity, hydraulicDiameter, muBulk);
    double Pr = PrandtlNumber(muBulk, c, k);
    
    return 1.86 * k / hydraulicDiameter * pow(Re * Pr * hydraulicDiameter / pathLength, 0.33) * pow(muBulk / muSurface, 0.14);
}

/// The surface heat transfer coefficient (BB2E, p514, eq:15.22)
double HeatTransferCoefficient(double hConv, double tInsul, double kInsul)
{
    return hConv / (1.0 + hConv * tInsul / kInsul);
}







