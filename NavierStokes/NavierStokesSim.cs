using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public class NavierStokesSim : MonoBehaviour
{
    public NavierStokesSettings Settings;
    [HideInInspector] public Shader NavierStokesSimShader;
    Material smat;

    public Material outputMaterial;

    [Header("Mesh Injector")]

    public Material ObjectVelocityMaterial;
    public Camera CustomVelocityRenderer;
    RenderTextureDoubleBuffered density, velocity, pressure;
    
    private RenderTexture divergence, curl;

    int passDisplay, passBackground, 
        passDisplayShading, passSplat, 
        passAdvection, passDivergence, 
        passCurl, passVorticity, 
        passPressure, passGradientSubtract, 
        passClear;
    
    void Start()
    {
        int dyeRes = Settings.DyeRes;
        int simRes = Settings.SimulationRes;
        density     = new RenderTextureDoubleBuffered(dyeRes, dyeRes, 0, RenderTextureFormat.ARGBHalf, "density");
        velocity    = new RenderTextureDoubleBuffered(simRes, simRes, 0, RenderTextureFormat.RGHalf, "velocity");
        divergence  = new RenderTexture(simRes, simRes, 0, RenderTextureFormat.RHalf);
        divergence.name = "divergence";
        divergence.Create();
        Graphics.Blit(Texture2D.blackTexture, divergence);
        curl        = new RenderTexture(simRes, simRes, 0, RenderTextureFormat.RHalf);
        curl.name = "curl";
        curl.Create();
        Graphics.Blit(Texture2D.blackTexture, curl);
        pressure    = new RenderTextureDoubleBuffered(simRes, simRes, 0, RenderTextureFormat.RHalf, "pressure");

        smat = new Material(NavierStokesSimShader);
        smat.hideFlags = HideFlags.DontSave;
        passDisplay             = smat.FindPass("DISPLAY");
        passBackground          = smat.FindPass("BACKGROUND");
        passDisplayShading      = smat.FindPass("DISPLAY_SHADING");
        passSplat               = smat.FindPass("SPLAT");
        passAdvection           = smat.FindPass("ADVECTION");
        passDivergence          = smat.FindPass("DIVERGENCE");
        passCurl                = smat.FindPass("CURL");
        passVorticity           = smat.FindPass("VORTICITY");
        passPressure            = smat.FindPass("PRESSURE");
        passGradientSubtract    = smat.FindPass("GRADIENT_SUBTRACT");
        passClear               = smat.FindPass("CLEAR");
    }
    const float e_rcp = 0.367879441171f; // = 1.0 / e
    public GameObject ObjectToDraw;

    void DrawMeshes() {
        
        Mesh customMesh = ObjectToDraw.GetComponent<MeshFilter>().sharedMesh;
       
        if(customMesh == null) { return;}
        
        CustomVelocityRenderer.targetTexture = velocity.Get(); // pass a rendertexture to get the correct projection matrix
        CustomVelocityRenderer.enabled = false;
        //NOTE: I could use a replacement shader but it's not working 100% for me, so here goes the manuall rendering...
        // compute projection * view matrix
        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(CustomVelocityRenderer.projectionMatrix, true);
        Matrix4x4 viewMatrix = CustomVelocityRenderer.transform.worldToLocalMatrix;
        Matrix4x4 finalModelViewProjection = projectionMatrix * viewMatrix * ObjectToDraw.transform.localToWorldMatrix;
        Shader.SetGlobalMatrix("custom_ObjectToClip", finalModelViewProjection);



        // setup material

       
        var prevRenderTarget = RenderTexture.active;
        
        // draw velocity
        Graphics.SetRenderTarget(velocity.Get());
        int targetTextureSize = velocity.Get().width;
        GL.Viewport(new Rect(0, 0, targetTextureSize, targetTextureSize));
        ObjectVelocityMaterial.SetFloat("_EmmitDensity", 0.0f);
        ObjectVelocityMaterial.SetPass(0); 
        Graphics.DrawMeshNow(customMesh, Matrix4x4.identity);

        // draw density
        Graphics.SetRenderTarget(density.Get());
        targetTextureSize = density.Get().width;
        GL.Viewport(new Rect(0, 0, targetTextureSize, targetTextureSize));
        ObjectVelocityMaterial.SetFloat("_EmmitDensity", 1.0f);
        ObjectVelocityMaterial.SetFloat("_Density", Settings.EmittiedDensity);
        ObjectVelocityMaterial.SetPass(0); 
        Graphics.DrawMeshNow(customMesh, Matrix4x4.identity);

        if(prevRenderTarget != null) { RenderTexture.active = prevRenderTarget;}
        
    }

    // Update is called once per frame
    void Update()
    {
        if(Settings.DemoMode) { 
            Splat();
        }

        if(ObjectToDraw != null) {
            DrawMeshes();
        }
        

        float vorticity = Settings.Vorticity;
        float TimeScale = Settings.TimeScale;
        float dt = Time.smoothDeltaTime;

        // CustomVelocityRenderer.targetTexture = velocity.Get();
        // CustomVelocityRenderer.RenderWithShader(ObjectVelocityShader, "NavierStokes");
        
        // CustomVelocityRenderer.SetReplacementShader(ObjectVelocityShader, null);
      
        smat.SetTexture("uVelocity", velocity.Get());
        smat.SetVector("texelSize", Vector2.one * (1f / velocity.width));
        Graphics.Blit(null, curl, smat, passCurl);

        smat.SetVector("texelSize", Vector2.one * (1f / velocity.width));
        smat.SetTexture("uVelocity", velocity.Get());
        smat.SetTexture("uCurl", curl);
        smat.SetFloat("curl", vorticity);
        smat.SetFloat("dt", dt * TimeScale);
        velocity.Swap();
        Graphics.Blit(null, velocity.Get(), smat, passVorticity);
        
        smat.SetVector("texelSize", Vector2.one * (1f / divergence.width));
        smat.SetTexture("uVelocity", velocity.Get());
        Graphics.Blit(null, divergence, smat, passDivergence);

        smat.SetVector("texelSize", Vector2.one * (1f / pressure.width));
        smat.SetTexture("uTexture", pressure.Get());
        smat.SetFloat("value", Mathf.Pow(Settings.PressureDissipation, e_rcp)); //TODO: * deltaTime???
        pressure.Swap();
        Graphics.Blit(null, pressure.Get(), smat, passClear);

        smat.SetVector("texelSize", Vector2.one * (1f / pressure.width));
        smat.SetTexture("uDivergence", divergence);
        smat.SetTexture("uPressure", pressure.Get());
        for (int i = 0; i < Settings.PressureIterations; i++) {
            smat.SetTexture("uPressure", pressure.Get());
            pressure.Swap();
            Graphics.Blit(null, pressure.Get(), smat, passPressure);       
        }

        smat.SetVector("texelSize", Vector2.one * (1f / pressure.width));
        smat.SetTexture("uVelocity", velocity.Get());
        smat.SetTexture("uPressure", pressure.Get());
        velocity.Swap();
        Graphics.Blit(null, velocity.Get(), smat, passGradientSubtract);  

        smat.SetVector("texelSize", Vector2.one * (1f / velocity.width));
        smat.SetTexture("uVelocity", velocity.Get());
        smat.SetTexture("uSource", velocity.Get());
        smat.SetFloat("dt", dt * TimeScale);
        smat.SetFloat("dissipation", Mathf.Pow(Settings.VelocityDissipation, e_rcp));
        velocity.Swap();
        Graphics.Blit(null, velocity.Get(), smat, passAdvection);

        smat.SetVector("texelSize", Vector2.one * (1f / velocity.width));
        smat.SetTexture("uVelocity", velocity.Get());
        smat.SetTexture("uSource", density.Get());
        smat.SetFloat("dissipation", Mathf.Pow(Settings.DensityDissipation, e_rcp));
        density.Swap();
        Graphics.Blit(null, density.Get(), smat, passAdvection);

        switch(Settings.OutputLayer) {
            case NavierStokeOutputLayers.curl:        outputMaterial.mainTexture = curl; break;
            case NavierStokeOutputLayers.density:     outputMaterial.mainTexture = density.Get(); break;
            case NavierStokeOutputLayers.divergence:  outputMaterial.mainTexture = divergence; break;
            case NavierStokeOutputLayers.pressure:    outputMaterial.mainTexture = pressure.Get(); break;
            case NavierStokeOutputLayers.velocity:    outputMaterial.mainTexture = velocity.Get(); break; 
        }
      

    }

    private Vector2 objectPos = Vector2.zero, objectTarget = Vector2.one;
    Vector2 StrechtToFullRange(Vector2 v) { return new Vector2(v.x * 2.0f - 1.0f, v.y * 2.0f - 1.0f);}
    Vector2 StrechtToLimitedRange(Vector2 v) {return new Vector2(v.x * 0.5f + 0.5f, v.y * 0.5f + 0.5f);}
    public void Splat() {
        Vector2 newObjectPos = Vector2.MoveTowards(objectPos, objectTarget, Time.deltaTime * 1f );
        if(newObjectPos == objectTarget) { objectTarget = StrechtToLimitedRange(Random.onUnitSphere);}
        Vector2 objectVelocity = StrechtToFullRange(newObjectPos) - StrechtToFullRange(objectPos);
        objectPos = newObjectPos;
        smat.SetTexture("uTarget", velocity.Get());
        smat.SetFloat("aspectRatio", 1f);
        smat.SetVector("targetPoint", (objectPos));
        smat.SetVector("color", objectVelocity * 10000f);
        smat.SetFloat("radius", Settings.SplatRadius / 100.0f);
        velocity.Swap();
        Graphics.Blit(null, velocity.Get(), smat, passSplat);
        
        smat.SetTexture("uTarget", density.Get());
        smat.SetColor("color", Color.white);
       density.Swap();
       Graphics.Blit(null, density.Get(), smat, passSplat);

    }
    class RenderTextureDoubleBuffered : System.IDisposable{
        private RenderTexture A, B;
        public RenderTextureDoubleBuffered(int width, int height, int depth, RenderTextureFormat format, string debugName){
            A = new RenderTexture(width, height, depth, format );
            A.name = debugName + "A";
            B = new RenderTexture(width, height, depth, format );
            B.name = debugName + "B";
            A.wrapMode = TextureWrapMode.Clamp;
            B.wrapMode = TextureWrapMode.Clamp;
            A.Create();
            B.Create();

            Graphics.Blit(Texture2D.blackTexture, A);
            Graphics.Blit(Texture2D.blackTexture, B);
        }

        private bool shouldReturnTextureA;
        public void Swap(){
            shouldReturnTextureA = !shouldReturnTextureA;
        }
        public RenderTexture Get() {      
            return shouldReturnTextureA ? A : B;
        }
        public void Dispose(){
            A.Release();
            B.Release();
        }

        public int width { get{return A.width;}}
    }
}
