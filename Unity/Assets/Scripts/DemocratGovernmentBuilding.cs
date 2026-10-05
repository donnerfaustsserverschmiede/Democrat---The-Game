using System.Collections.Generic;
using UnityEngine;

public sealed class DemocratGovernmentBuilding
{
    readonly Dictionary<Color, Material> materials = new Dictionary<Color, Material>();
    Transform root;
    Material wall, floor, darkFloor, wood, glass, metal, fabric, green, accent, white, screen;

    public Transform Build()
    {
        root = new GameObject("Democrat Government Building").transform;
        BuildMaterials();
        BuildFoundation();
        BuildMainCirculation();
        BuildPublicRooms();
        BuildParliamentaryRooms();
        BuildPoliticalRooms();
        BuildMediaRooms();
        BuildServiceRooms();
        BuildExterior();
        AddCapacityZones();
        StaticBatchingUtility.Combine(root.gameObject);
        return root;
    }

    void BuildMaterials()
    {
        wall = Mat(new Color(.70f,.72f,.75f));
        floor = Mat(new Color(.18f,.20f,.23f));
        darkFloor = Mat(new Color(.10f,.12f,.14f));
        wood = Mat(new Color(.38f,.24f,.13f));
        glass = Mat(new Color(.10f,.32f,.43f));
        metal = Mat(new Color(.32f,.35f,.38f));
        fabric = Mat(new Color(.16f,.22f,.29f));
        green = Mat(new Color(.16f,.32f,.24f));
        accent = Mat(new Color(.70f,.53f,.20f));
        white = Mat(new Color(.88f,.89f,.90f));
        screen = Mat(new Color(.04f,.12f,.17f));
    }

    Material Mat(Color c)
    {
        if (materials.TryGetValue(c, out var existing)) return existing;
        var m = new Material(Shader.Find("Standard"));
        m.color = c;
        materials[c] = m;
        return m;
    }

    GameObject Cube(string name, Vector3 p, Vector3 s, Material m, bool collider=true)
    {
        var g = GameObject.CreatePrimitive(PrimitiveType.Cube);
        g.name = name;
        g.transform.SetParent(root, false);
        g.transform.position = p;
        g.transform.localScale = s;
        g.GetComponent<Renderer>().sharedMaterial = m;
        if (!collider)
        {
            var c = g.GetComponent<Collider>();
            if (c) Object.Destroy(c);
        }
        g.isStatic = true;
        return g;
    }

    void Floor(string name, Vector3 c, Vector2 size, Material m = null)
    {
        Cube(name, c, new Vector3(size.x,.20f,size.y), m ?? floor);
    }

    void Wall(string name, Vector3 c, Vector3 size, Material m = null)
    {
        Cube(name, c, size, m ?? wall);
    }

    void DoorWallX(string name, float x, float z, float length, float height, float doorCenter, float doorWidth)
    {
        float left = doorCenter - doorWidth * .5f;
        float right = doorCenter + doorWidth * .5f;
        float localMin = -length * .5f;
        float localMax = length * .5f;

        float aLen = left - localMin;
        float bLen = localMax - right;
        if (aLen > .2f) Wall(name+" L", new Vector3(x + localMin + aLen*.5f, height*.5f, z), new Vector3(aLen,height,.30f));
        if (bLen > .2f) Wall(name+" R", new Vector3(x + right + bLen*.5f, height*.5f, z), new Vector3(bLen,height,.30f));
        Wall(name+" Header", new Vector3(x + doorCenter,height-.45f,z), new Vector3(doorWidth,.9f,.30f));
    }

    void DoorWallZ(string name, float x, float z, float length, float height, float doorCenter, float doorWidth)
    {
        float a = doorCenter - doorWidth*.5f;
        float b = doorCenter + doorWidth*.5f;
        float min = -length*.5f;
        float max = length*.5f;

        float aLen = a-min;
        float bLen = max-b;
        if (aLen > .2f) Wall(name+" A", new Vector3(x, height*.5f, z+min+aLen*.5f), new Vector3(.30f,height,aLen));
        if (bLen > .2f) Wall(name+" B", new Vector3(x, height*.5f, z+b+bLen*.5f), new Vector3(.30f,height,bLen));
        Wall(name+" Header", new Vector3(x,height-.45f,z+doorCenter), new Vector3(.30f,.9f,doorWidth));
    }

    void Room(string name, Vector3 c, Vector2 size, float doorOnSouth, float height = 4.5f)
    {
        Floor(name+" Floor", c, size, floor);
        DoorWallX(name+" South", c.x, c.z-size.y*.5f, size.x, height, doorOnSouth, 2.4f);
        Wall(name+" North", new Vector3(c.x,height*.5f,c.z+size.y*.5f), new Vector3(size.x,height,.30f));
        Wall(name+" West", new Vector3(c.x-size.x*.5f,height*.5f,c.z), new Vector3(.30f,height,size.y));
        Wall(name+" East", new Vector3(c.x+size.x*.5f,height*.5f,c.z), new Vector3(.30f,height,size.y));
        Sign(name, new Vector3(c.x, height-.65f, c.z-size.y*.5f+.18f));
    }

    void BuildFoundation()
    {
        Floor("Main Building Floor", new Vector3(0,-.12f,35), new Vector2(100,140), darkFloor);
        Wall("North Exterior", new Vector3(0,5,105), new Vector3(100,10,.5f));
        Wall("South Exterior", new Vector3(0,5,-35), new Vector3(100,10,.5f));
        Wall("West Exterior", new Vector3(-50,5,35), new Vector3(.5f,10,140));
        Wall("East Exterior", new Vector3(50,5,35), new Vector3(.5f,10,140));
    }

    void BuildMainCirculation()
    {
        Floor("Entrance Plaza", new Vector3(0,.02f,-28), new Vector2(44,16), darkFloor);
        Floor("Central Atrium", new Vector3(0,.04f,0), new Vector2(30,28), floor);
        Floor("North Main Corridor", new Vector3(0,.04f,48), new Vector2(10,92), floor);
        Floor("West Main Corridor", new Vector3(-28,.04f,34), new Vector2(34,10), floor);
        Floor("East Main Corridor", new Vector3(28,.04f,34), new Vector2(34,10), floor);
        Floor("Media Corridor", new Vector3(0,.04f,86), new Vector2(70,10), floor);

        // Accessible circulation: open doorways connect every room to a public corridor.
        Wall("Atrium West", new Vector3(-15,2.5f,0), new Vector3(.3f,5,28));
        Wall("Atrium East", new Vector3(15,2.5f,0), new Vector3(.3f,5,28));
        DoorWallZ("Atrium North", -15,14,28,5,0,4);
        DoorWallZ("Atrium North East", 15,14,28,5,0,4);

        // Large central staircase/ramp is decorative but walkable.
        Ramp(new Vector3(0,.1f,14), new Vector3(7,2.2f,14), 0);
        Ramp(new Vector3(0,2.2f,22), new Vector3(7,2.2f,14), 180);

        Reception(new Vector3(0,0,-15));
        SeatingArea(new Vector3(-9,0,-3), 5, 3);
        SeatingArea(new Vector3(9,0,-3), 5, 3);
        SecurityCheckpoint(new Vector3(0,0,-7));
        InformationDesk(new Vector3(0,0,-1));
    }

    void BuildPublicRooms()
    {
        Room("CAFETERIA", new Vector3(-28,0,-5), new Vector2(32,18), 0);
        TableCluster(new Vector3(-28,0,-5), 5, 4);

        Room("TOILETS WEST", new Vector3(-42,0,8), new Vector2(12,14), 0);
        Fixtures(new Vector3(-42,0,8), 3);

        Room("TOILETS EAST", new Vector3(42,0,8), new Vector2(12,14), 0);
        Fixtures(new Vector3(42,0,8), 3);

        Room("CHANGING ROOM", new Vector3(28,0,-5), new Vector2(32,18), 0);
        Lockers(new Vector3(28,0,-5), 12);

        Room("INFORMATION AREA", new Vector3(-28,0,18), new Vector2(32,18), 0);
        DeskRow(new Vector3(-28,0,18), 5);

        Room("VISITOR LOUNGE", new Vector3(28,0,18), new Vector2(32,18), 0);
        SeatingArea(new Vector3(28,0,18), 8, 5);
    }

    void BuildParliamentaryRooms()
    {
        Room("PLENARY HALL", new Vector3(0,0,52), new Vector2(46,34), 0, 8);
        PlenaryFurniture(new Vector3(0,0,52));

        Room("LARGE COMMITTEE ROOM", new Vector3(-28,0,35), new Vector2(30,20), 0);
        Boardroom(new Vector3(-28,0,35), 10);

        Room("MEDIUM COMMITTEE ROOM", new Vector3(28,0,35), new Vector2(30,20), 0);
        Boardroom(new Vector3(28,0,35), 8);

        Room("SMALL SESSION ROOM", new Vector3(-28,0,58), new Vector2(30,20), 0);
        Boardroom(new Vector3(-28,0,58), 6);

        Room("CONFERENCE ROOM", new Vector3(28,0,58), new Vector2(30,20), 0);
        Boardroom(new Vector3(28,0,58), 10);

        Room("ELECTION HALL", new Vector3(0,0,80), new Vector2(46,22), 0);
        ElectionFurniture(new Vector3(0,0,80));
    }

    void BuildPoliticalRooms()
    {
        string[] names =
        {
            "FACTION ROOM A","FACTION ROOM B","FACTION ROOM C","FACTION ROOM D",
            "FACTION ROOM E","FACTION ROOM F","MEMBER OFFICE 01","MEMBER OFFICE 02",
            "MEMBER OFFICE 03","MEMBER OFFICE 04","LEADERSHIP OFFICE","MEETING ROOM A"
        };

        Vector3[] positions =
        {
            new Vector3(-42,0,34),new Vector3(-42,0,50),new Vector3(-42,0,66),
            new Vector3(42,0,34),new Vector3(42,0,50),new Vector3(42,0,66),
            new Vector3(-28,0,75),new Vector3(-14,0,75),new Vector3(14,0,75),
            new Vector3(28,0,75),new Vector3(-42,0,82),new Vector3(42,0,82)
        };

        for(int i=0;i<names.Length;i++)
        {
            Room(names[i], positions[i], new Vector2(12,12), 0, 3.8f);
            OfficeFurniture(positions[i], i < 6);
        }
    }

    void BuildMediaRooms()
    {
        Room("PRESS CONFERENCE ROOM", new Vector3(-28,0,96), new Vector2(30,16), 0);
        PressFurniture(new Vector3(-28,0,96));

        Room("TV STUDIO", new Vector3(28,0,96), new Vector2(30,16), 0);
        StudioFurniture(new Vector3(28,0,96));

        Room("INTERVIEW AREA", new Vector3(0,0,102), new Vector2(20,10), 0);
        InterviewFurniture(new Vector3(0,0,102));

        Room("PRESS WORKSTATIONS", new Vector3(-42,0,99), new Vector2(12,12), 0);
        DeskRow(new Vector3(-42,0,99), 3);

        Room("TECHNICAL MEDIA", new Vector3(42,0,99), new Vector2(12,12), 0);
        RackRow(new Vector3(42,0,99), 5);
    }

    void BuildServiceRooms()
    {
        Room("SECURITY ROOM", new Vector3(-42,0,-8), new Vector2(12,12), 0);
        DeskRow(new Vector3(-42,0,-8), 2);

        Room("STORAGE", new Vector3(42,0,-8), new Vector2(12,12), 0);
        StorageShelves(new Vector3(42,0,-8), 4);

        Room("TECHNICAL ROOM", new Vector3(-42,0,22), new Vector2(12,12), 0);
        RackRow(new Vector3(-42,0,22), 4);

        Room("STAFF ROOM", new Vector3(42,0,22), new Vector2(12,12), 0);
        SeatingArea(new Vector3(42,0,22), 4, 2);

        Room("EMERGENCY EXIT WEST", new Vector3(-48,0,55), new Vector2(4,12), 0, 3.5f);
        Room("EMERGENCY EXIT EAST", new Vector3(48,0,55), new Vector2(4,12), 0, 3.5f);
    }

    void BuildExterior()
    {
        // Fictional scenery visible through the windows. No official symbols or real government branding.
        for(int z=-20; z<=105; z+=18)
        {
            Cube("Window City Backdrop L", new Vector3(-50.5f,6,z), new Vector3(.2f,9,15), glass, false);
            Cube("Window City Backdrop R", new Vector3(50.5f,6,z), new Vector3(.2f,9,15), glass, false);
        }

        for(int i=-4;i<=4;i++)
        {
            float x=i*10f;
            Cube("Fictional Building", new Vector3(x,4,116), new Vector3(7,8+Mathf.Abs(i)*2,5), metal, false);
            for(int w=0;w<3;w++)
                Cube("Lit Window", new Vector3(x-2+w*2,5.5f,113.45f), new Vector3(1,.7f,.08f), accent, false);
        }

        Cube("Democrat Entrance Canopy", new Vector3(0,5,-25), new Vector3(26,.5f,8), metal, false);
        Cube("Democrat Entrance Accent", new Vector3(0,3.5f,-28.9f), new Vector3(14,3,.2f), accent, false);
        Sign("DEMOCRAT", new Vector3(0,4.2f,-29.1f), 1.2f);
    }

    void AddCapacityZones()
    {
        // Logical capacity is deliberately separated from rendering.
        var config = new GameObject("Democrat World Capacity 10000");
        config.transform.SetParent(root, false);
        var capacity = config.AddComponent<DemocratWorldCapacity>();
        capacity.logicalPlayerCapacity = 10000;
        capacity.clientInterestRadius = 55f;
        capacity.recommendedVisibleRemotePlayers = 80;
    }

    void Reception(Vector3 p)
    {
        Cube("Reception Counter", p+new Vector3(0,1.1f,0), new Vector3(12,2,1.3f), wood);
        for(int i=-2;i<=2;i++) Chair(p+new Vector3(i*2.1f,0,2.5f));
        Sign("RECEPTION", p+new Vector3(0,3,-.8f));
    }

    void SecurityCheckpoint(Vector3 p)
    {
        for(int i=-2;i<=2;i++) Cube("Security Gate",p+new Vector3(i*2.2f,1,0),new Vector3(1.4f,2,.5f),metal);
        Cube("Security Desk",p+new Vector3(0,1,2.2f),new Vector3(7,2,1),wood);
    }

    void InformationDesk(Vector3 p)
    {
        Cube("Information Counter",p+new Vector3(0,1,0),new Vector3(8,2,1),wood);
        for(int i=-2;i<=2;i++) Screen(p+new Vector3(i*1.4f,2.1f,-.55f));
    }

    void SeatingArea(Vector3 p,int seats,int rows)
    {
        for(int r=0;r<rows;r++)
            for(int i=0;i<seats;i++)
                Chair(p+new Vector3((i-(seats-1)*.5f)*1.8f,0,r*2.0f));
    }

    void TableCluster(Vector3 p,int columns,int rows)
    {
        for(int z=0;z<rows;z++)
        {
            Vector3 q=p+new Vector3(0,0,(z-(rows-1)*.5f)*4);
            Cube("Cafeteria Table",q+Vector3.up*.9f,new Vector3(7,.18f,2),wood);
            for(int x=-2;x<=2;x++) Chair(q+new Vector3(x*1.25f,0,1.7f));
            for(int x=-2;x<=2;x++) Chair(q+new Vector3(x*1.25f,0,-1.7f));
        }
    }

    void PlenaryFurniture(Vector3 p)
    {
        Cube("Presidium",p+new Vector3(0,1.1f,11),new Vector3(20,2,2),wood);
        Cube("Lectern",p+new Vector3(0,1.4f,7),new Vector3(1.2f,2.8f,.8f),wood);
        for(int row=0;row<6;row++)
        {
            float z=p.z+5-row*3.2f;
            for(int i=-4;i<=4;i++)
            {
                Cube("Parliament Desk",new Vector3(p.x+i*2.7f,.8f,z),new Vector3(2.2f,.18f,1),wood);
                Chair(new Vector3(p.x+i*2.7f,0,z-1.1f));
            }
        }
        for(int i=-5;i<=5;i++)
            Cube("Visitor Gallery",new Vector3(p.x+i*2.2f,3.3f,p.z-13),new Vector3(1.7f,.18f,3),metal);
        Sign("PLENUM",p+new Vector3(0,7.2f,-15),1.0f);
    }

    void ElectionFurniture(Vector3 p)
    {
        for(int row=0;row<2;row++)
            for(int i=-5;i<=5;i++)
            {
                Vector3 q=p+new Vector3(i*3.5f,0,row*6-2);
                Cube("Voting Booth",q+Vector3.up*1.3f,new Vector3(2.5f,2.6f,2),fabric);
                Cube("Ballot Box",q+new Vector3(0,.65f,1.3f),new Vector3(1,.9f,1),metal);
            }
        Cube("Election Results Display",p+new Vector3(0,2.6f,8),new Vector3(16,5,.3f),screen);
        Sign("WAHLHALLE",p+new Vector3(0,3,-9),1.0f);
    }

    void Boardroom(Vector3 p,int seats)
    {
        Cube("Meeting Table",p+Vector3.up*.9f,new Vector3(Mathf.Max(6,seats*.8f),.18f,4),wood);
        for(int i=0;i<seats;i++)
        {
            float a=(i/(float)seats)*Mathf.PI*2;
            Chair(p+new Vector3(Mathf.Cos(a)*Mathf.Max(3,seats*.42f),0,Mathf.Sin(a)*2.3f));
        }
        Screen(p+new Vector3(0,3, -3.5f));
    }

    void OfficeFurniture(Vector3 p,bool faction)
    {
        Cube(faction ? "Faction Desk" : "Office Desk",p+new Vector3(0,.9f,-2.2f),new Vector3(4,.18f,1.5f),wood);
        Chair(p+new Vector3(0,0,-.7f));
        Screen(p+new Vector3(0,2.0f,-2.9f));
        Cube("Office Cabinet",p+new Vector3(3,1.2f,2),new Vector3(1,.2f,3),metal);
    }

    void PressFurniture(Vector3 p)
    {
        Cube("Press Podium",p+new Vector3(0,1.2f,4),new Vector3(2,2.4f,1),wood);
        for(int i=-4;i<=4;i++) Chair(p+new Vector3(i*2.1f,0,-1));
        for(int i=-3;i<=3;i++) Screen(p+new Vector3(i*2.7f,1.6f,3.2f));
    }

    void StudioFurniture(Vector3 p)
    {
        Cube("Studio Desk",p+new Vector3(0,1.1f,0),new Vector3(8,2.2f,2),wood);
        for(int i=-1;i<=1;i++) Chair(p+new Vector3(i*2.4f,0,-1.7f));
        Cube("Studio Camera",p+new Vector3(0,1.4f,5),new Vector3(1.2f,2.2f,1.2f),metal);
        Screen(p+new Vector3(0,2.8f,2.5f));
    }

    void InterviewFurniture(Vector3 p)
    {
        Chair(p+new Vector3(-2,0,0)); Chair(p+new Vector3(2,0,0));
        Cube("Interview Table",p+Vector3.up*.7f,new Vector3(5,.18f,1.2f),wood);
        Screen(p+new Vector3(0,2.4f,3.5f));
    }

    void DeskRow(Vector3 p,int count)
    {
        for(int i=0;i<count;i++)
        {
            float x=(i-(count-1)*.5f)*2.7f;
            Cube("Desk",p+new Vector3(x,.9f,0),new Vector3(2.2f,.18f,1.3f),wood);
            Chair(p+new Vector3(x,0,1.2f));
        }
    }

    void RackRow(Vector3 p,int count)
    {
        for(int i=0;i<count;i++)
            Cube("Equipment Rack",p+new Vector3((i-(count-1)*.5f)*1.8f,1.4f,0),new Vector3(1.3f,2.8f,1),metal);
    }

    void StorageShelves(Vector3 p,int count)
    {
        for(int i=0;i<count;i++)
            Cube("Storage Shelf",p+new Vector3((i-(count-1)*.5f)*2.2f,1.5f,0),new Vector3(1.5f,3,.8f),metal);
    }

    void Lockers(Vector3 p,int count)
    {
        for(int i=0;i<count;i++)
            Cube("Locker",p+new Vector3((i-(count-1)*.5f)*1.5f,1.3f,0),new Vector3(1.2f,2.6f,.8f),metal);
    }

    void Fixtures(Vector3 p,int count)
    {
        for(int i=0;i<count;i++)
        {
            float x=(i-(count-1)*.5f)*2.5f;
            Cube("Sanitary Fixture",p+new Vector3(x,.5f,0),new Vector3(1.4f,1,.8f),white);
        }
    }

    void Ramp(Vector3 p,Vector3 size,float yaw)
    {
        var g=Cube("Accessible Ramp",p,size,darkFloor);
        g.transform.rotation=Quaternion.Euler(0,yaw, Mathf.Sign(size.z)*Mathf.Atan2(size.y,size.z)*Mathf.Rad2Deg);
    }

    void Chair(Vector3 p)
    {
        Cube("Chair Seat",p+new Vector3(0,.45f,0),new Vector3(1,.15f,1),fabric);
        Cube("Chair Back",p+new Vector3(0,1,.35f),new Vector3(1,1,.15f),fabric);
    }

    void Screen(Vector3 p)
    {
        Cube("Display Screen",p,new Vector3(2.2f,1.3f,.12f),screen);
    }

    void Sign(string text,Vector3 p,float scale=.7f)
    {
        var go=new GameObject("Sign "+text);
        go.transform.SetParent(root,false);
        go.transform.position=p;
        var tm=go.AddComponent<TextMesh>();
        tm.text=text;
        tm.fontSize=32;
        tm.characterSize=.06f*scale;
        tm.anchor=TextAnchor.MiddleCenter;
        tm.alignment=TextAlignment.Center;
        tm.color=Color.white;
        go.transform.rotation=Quaternion.Euler(0,180,0);
    }
}
