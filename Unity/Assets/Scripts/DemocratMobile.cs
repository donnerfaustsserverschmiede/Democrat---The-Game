using UnityEngine;
using UnityEngine.UI;

public class DemocratMobile : MonoBehaviour
{
    CharacterController controller;
    Transform cameraPivot;
    float yaw, pitch = 12f, gravity;
    GameObject playerVisual;
    string firstName = "Vorname";
    string lastName = "Nachname";
    bool playing;

    void Start()
    {
        Application.targetFrameRate = 60;
        Screen.sleepTimeout = SleepTimeout.NeverSleep;
        BuildLighting();
        BuildGovernment();
        ShowCharacterCreation();
    }

    void BuildLighting()
    {
        var sun = new GameObject("Sun");
        var l = sun.AddComponent<Light>();
        l.type = LightType.Directional;
        l.intensity = 1.15f;
        sun.transform.rotation = Quaternion.Euler(48f,-25f,0);
        RenderSettings.ambientLight = new Color(.55f,.58f,.62f);
    }

    Material Mat(Color c)
    {
        var m = new Material(Shader.Find("Standard"));
        m.color = c;
        return m;
    }

    GameObject Cube(string name, Vector3 p, Vector3 s, Material mat, Transform parent=null)
    {
        var g = GameObject.CreatePrimitive(PrimitiveType.Cube);
        g.name = name;
        g.transform.position = p;
        g.transform.localScale = s;
        if(parent) g.transform.SetParent(parent);
        g.GetComponent<Renderer>().material = mat;
        return g;
    }

    void BuildGovernment()
    {
        var root = new GameObject("Democrat Government Building").transform;
        var wall=Mat(new Color(.72f,.74f,.77f));
        var floor=Mat(new Color(.20f,.22f,.25f));
        var glass=Mat(new Color(.18f,.42f,.55f,.45f));
        var gold=Mat(new Color(.72f,.55f,.20f));

        Room(root,"ENTRANCE HALL",Vector3.zero,new Vector3(18,5,16),wall,floor);
        Room(root,"RECEPTION",new Vector3(0,0,-12),new Vector3(12,4,5),wall,floor);
        Room(root,"PLENARY HALL",new Vector3(0,0,23),new Vector3(30,6,24),wall,floor);
        Room(root,"COMMITTEE WEST",new Vector3(-18,0,5),new Vector3(10,4.5f,9),wall,floor);
        Room(root,"COMMITTEE EAST",new Vector3(18,0,5),new Vector3(10,4.5f,9),wall,floor);
        Room(root,"ELECTION HALL",new Vector3(0,0,43),new Vector3(18,4.5f,12),wall,floor);

        for(int i=-4;i<=4;i++) Cube("Facade Glass",new Vector3(i*4.5f,2.4f,-20),new Vector3(3.9f,4.8f,.18f),glass,root);
        Cube("Entrance Accent",new Vector3(0,.08f,-8.05f),new Vector3(10,.16f,.4f),gold,root);

        var ground=GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.name="Government Plaza";
        ground.transform.localScale=Vector3.one*35f;
        ground.GetComponent<Renderer>().material=Mat(new Color(.16f,.18f,.20f));
    }

    void Room(Transform root,string name,Vector3 c,Vector3 size,Material wall,Material floor)
    {
        Cube(name+" Floor",c+Vector3.up*.0f,new Vector3(size.x,.2f,size.z),floor,root);
        Cube(name+" North",c+new Vector3(0,size.y/2,size.z/2),new Vector3(size.x,size.y,.35f),wall,root);
        Cube(name+" South",c+new Vector3(0,size.y/2,-size.z/2),new Vector3(size.x,size.y,.35f),wall,root);
        Cube(name+" West",c+new Vector3(-size.x/2,size.y/2,0),new Vector3(.35f,size.y,size.z),wall,root);
        Cube(name+" East",c+new Vector3(size.x/2,size.y/2,0),new Vector3(.35f,size.y,size.z),wall,root);
    }

    Canvas CanvasRoot()
    {
        var go=new GameObject("Mobile UI");
        var c=go.AddComponent<Canvas>();
        c.renderMode=RenderMode.ScreenSpaceOverlay;
        var s=go.AddComponent<CanvasScaler>();
        s.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;
        s.referenceResolution=new Vector2(1080,1920);
        go.AddComponent<GraphicRaycaster>();
        return c;
    }

    Text Label(Canvas c,string text,int size,Vector2 anchor,Vector2 pos,Vector2 dims)
    {
        var go=new GameObject("Label");
        go.transform.SetParent(c.transform,false);
        var t=go.AddComponent<Text>();
        t.text=text; t.fontSize=size; t.color=Color.white;
        t.alignment=TextAnchor.MiddleCenter;
        var r=t.rectTransform;
        r.anchorMin=r.anchorMax=anchor; r.pivot=anchor;
        r.anchoredPosition=pos; r.sizeDelta=dims;
        return t;
    }

    InputField Field(Canvas c,string placeholder,Vector2 pos)
    {
        var go=new GameObject("Input "+placeholder);
        go.transform.SetParent(c.transform,false);
        var img=go.AddComponent<Image>();
        img.color=new Color(.08f,.09f,.11f,.95f);
        var f=go.AddComponent<InputField>();
        f.textComponent=TextComponent(go,20);
        f.placeholder=TextComponent(go,20);
        f.placeholder.text=placeholder;
        var r=go.GetComponent<RectTransform>();
        r.anchorMin=r.anchorMax=new Vector2(.5f,.5f);
        r.pivot=new Vector2(.5f,.5f); r.anchoredPosition=pos; r.sizeDelta=new Vector2(650,95);
        return f;
    }

    Text TextComponent(GameObject parent,int size)
    {
        var go=new GameObject("Text");
        go.transform.SetParent(parent.transform,false);
        var t=go.AddComponent<Text>();
        t.fontSize=size; t.color=Color.white;
        t.alignment=TextAnchor.MiddleCenter;
        var r=t.rectTransform;
        r.anchorMin=Vector2.zero; r.anchorMax=Vector2.one;
        r.offsetMin=new Vector2(25,0); r.offsetMax=new Vector2(-25,0);
        return t;
    }

    Button Button(Canvas c,string text,Vector2 pos)
    {
        var go=new GameObject("Button "+text);
        go.transform.SetParent(c.transform,false);
        var img=go.AddComponent<Image>(); img.color=new Color(.12f,.16f,.22f,.98f);
        var b=go.AddComponent<Button>();
        Label(c,text,30,new Vector2(.5f,.5f),pos,new Vector2(650,95)).transform.SetParent(go.transform,false);
        var r=go.GetComponent<RectTransform>();
        r.anchorMin=r.anchorMax=new Vector2(.5f,.5f); r.pivot=new Vector2(.5f,.5f);
        r.anchoredPosition=pos; r.sizeDelta=new Vector2(650,95);
        return b;
    }

    void ShowCharacterCreation()
    {
        var c=CanvasRoot();
        Label(c,"DEMOCRAT",64,new Vector2(.5f,.5f),new Vector2(0,650),new Vector2(800,100));
        Label(c,"CHARAKTER ERSTELLEN",34,new Vector2(.5f,.5f),new Vector2(0,560),new Vector2(800,70));
        var first=Field(c,"Vorname",new Vector2(0,400));
        var last=Field(c,"Nachname",new Vector2(0,285));
        var b=Button(c,"GEBÄUDE BETRETEN",new Vector2(0,120));
        b.onClick.AddListener(()=> {
            firstName=string.IsNullOrWhiteSpace(first.text)?"Spieler":first.text;
            lastName=string.IsNullOrWhiteSpace(last.text)?"Donnerfaust":last.text;
            Destroy(c.gameObject);
            SpawnPlayer();
        });
    }

    void SpawnPlayer()
    {
        playing=true;
        var go=new GameObject("Player "+firstName+" "+lastName);
        go.transform.position=new Vector3(0,1,-5.5f);
        controller=go.AddComponent<CharacterController>();
        controller.height=1.8f; controller.radius=.32f; controller.center=Vector3.up*.9f;

        playerVisual=GameObject.CreatePrimitive(PrimitiveType.Capsule);
        playerVisual.transform.SetParent(go.transform,false);
        playerVisual.transform.localPosition=Vector3.up*.9f;
        playerVisual.transform.localScale=new Vector3(.62f,.9f,.62f);
        playerVisual.GetComponent<Renderer>().material=Mat(new Color(.08f,.12f,.18f));

        var head=GameObject.CreatePrimitive(PrimitiveType.Sphere);
        head.transform.SetParent(go.transform,false);
        head.transform.localPosition=new Vector3(0,1.95f,0);
        head.transform.localScale=Vector3.one*.42f;
        head.GetComponent<Renderer>().material=Mat(new Color(.78f,.62f,.48f));

        cameraPivot=new GameObject("Camera Pivot").transform;
        cameraPivot.SetParent(go.transform,false);
        cameraPivot.localPosition=new Vector3(0,1.45f,0);

        var cam=new GameObject("Player Camera");
        cam.tag="MainCamera";
        cam.AddComponent<Camera>();
        cam.AddComponent<AudioListener>();
        cam.transform.SetParent(cameraPivot,false);
        cam.transform.localPosition=new Vector3(0,1.65f,-5.2f);
        cam.transform.localRotation=Quaternion.Euler(5,0,0);

        var ui=CanvasRoot();
        Label(ui,"DEMOCRAT",34,new Vector2(.5f,1),new Vector2(0,-45),new Vector2(500,70));
        Label(ui,firstName+" "+lastName+"\nEingangshalle",24,new Vector2(0,1),new Vector2(25,-35),new Vector2(430,110));
        Label(ui,"LINKS: BEWEGEN    RECHTS: KAMERA",20,new Vector2(.5f,0),new Vector2(0,45),new Vector2(800,60));
    }

    void Update()
    {
        if(!playing || controller==null) return;

        Vector2 moveInput=Vector2.zero;
        foreach(var t in Input.touches)
        {
            if(t.position.x<Screen.width*.45f)
                moveInput=Vector2.ClampMagnitude((t.position-new Vector2(Screen.width*.18f,Screen.height*.18f))/(Screen.height*.12f),1f);
            else if(t.phase==TouchPhase.Moved)
            {
                yaw+=t.deltaPosition.x*.08f;
                pitch=Mathf.Clamp(pitch-t.deltaPosition.y*.06f,-5f,35f);
            }
        }

        transformRotation(yaw,pitch);
        Vector3 move=(transform.forward*moveInput.y+transform.right*moveInput.x);
        if(move.sqrMagnitude>1) move.Normalize();
        if(controller.isGrounded) gravity=-1f; else gravity+=Physics.gravity.y*Time.deltaTime;
        move.y=gravity;
        controller.Move(move*3.8f*Time.deltaTime);
    }

    void transformRotation(float y,float p)
    {
        controller.transform.rotation=Quaternion.Euler(0,y,0);
        cameraPivot.localRotation=Quaternion.Euler(p,0,0);
    }
}
