//
//  BluebookThermalFunctions.h
//  PCH_TransformerCooling
//
//  Created by Peter Huber on 2018-09-10.
//  Copyright © 2018 Huberis Technologies. All rights reserved.
//

#ifndef BluebookThermalFunctions_h
#define BluebookThermalFunctions_h

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>

#define SPECIFIC_HEAT_OF_OIL                            1880.0  // J/kg (referred to as "c" in BB2E Section 15)
#define FLUID_DENSITY_OF_OIL                            867.0   // kg/m3 (referred to as "⍴" in BB2E Section 15)
#define THERMAL_CONDUCTIVITY_OF_OIL                     0.11    // W/m•C (referred to as "k" in BB2E Section 15)
#define THERMAL_CONDUCTIVITY_OF_PAPER                   0.16    // W/m•C (referred to as "k" in BB2E Section 15)
#define VOLUME_COEFFICIENT_OF_THERMAL_EXPANSION_OF_OIL  6.8E-4  // per degree K (referred to as "𝛽" in BB2E Section 15)
#define ACCELERATION_DUE_TO_GRAVITY                     9.80665 // m/s2 (referred to as "g" in BB2E Section 15)


/// General function to calculate hydraulic diameter for an arbitrary shape, given the cross-secitonal area and the wetted perimeter
double HydraulicDiameter(double xSect, double wPerimeter);

/// Specific function to calculate the hydraulic diameter of a rectangular duct
double HydraulicDiameterOfRect(double w, double h);

/// The Reynolds number (Bluebook 2E, page 510, eq:15.2)
double ReynoldsNumber(double fDensity, double fVelocity, double hydraulicDiameter, double fViscosity);

/// Friction coefficient for laminar flows in circular ducts (BB2E, p510)
double FrictionCoefficientCircularDuct(double reynoldsNumber);

/// Friction coefficient for laminar flows in rectangular ducts (BB2E, p510, eq:15.3)
double FrictionCoefficientRectangularDuct(double w, double h, double reynoldsNumber);

/// Pressure change in a rectangular duct from point 1 to point 2 (BB2E, p510, eq:15.5)
double PressureChangeRectangularDuct(double w, double h, double fViscosity, double pathLength, double fVelocity);

/// Alternate method of calculating pressure change, taking K and D as parameters
double PressureChangeUsingKandD(double K, double D, double fViscosity, double pathLength, double fVelocity);

/// Pressure change in a coil (used to come up with the pressure at the bottom of the coil - BB2E, p513, eq:15.16) as caused by the temperature difference between the top and bottom.
double PressureChangeInCoil(double fDensity, double coilHt, double deltaT);

/// Calculate K(a,b) (BB2E, p511, eq:15.4
double K(double a, double b);

/// Oil viscosity (BB2E, p511, eq:15.6)
double OilViscosity(double tempInC);

/// Initial oil velocity v0 using the given losses (BB2E, p513, eq:15.17)
double InitialOilVelocity(double coilLoss, double inletArea, double deltaT);

/// Prandtl number (BB2E, p514)
double PrandtlNumber(double fViscosity, double fSpecificHeat, double fThermalConductivity);

/// Convection heat transfer coefficient (BB2E, p514, eq:15.23)
double ConvectionCoefficient(double hydraulicDiameter, double pathLength, double bulkOilTemp, double gradient, double fVelocity);

/// The surface heat transfer coefficient (BB2E, p514, eq:15.22)
double HeatTransferCoefficient(double hConv, double tInsul, double kInsul);


#endif /* BluebookThermalFunctions_h */
