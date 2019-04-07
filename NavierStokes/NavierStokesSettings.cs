using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(menuName = "Navier-Stokes Settings")]
public class NavierStokesSettings : ScriptableObject
{
    public int SimulationRes = 256, DyeRes = 256;
    public float Vorticity = 25f, TimeScale = 1f;
    [Range(0f, 1f)]
    public float PressureDissipation = 0.9f, VelocityDissipation = 0.9f, DensityDissipation = 0.9f;
    [Range(0, 50)]
    public int PressureIterations = 4;
    public NavierStokeOutputLayers OutputLayer;

    public bool DemoMode = true;
    public float SplatRadius, EmittiedDensity;


}

    public enum NavierStokeOutputLayers{
        density,
        velocity,
        divergence,
        curl,
        pressure
    }
