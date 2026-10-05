using UnityEngine;
using UnityEngine.UI;

public class DemocratMobile : MonoBehaviour
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Bootstrap()
    {
        if (FindFirstObjectByType<DemocratMobile>() == null)
            new GameObject("Democrat Mobile Bootstrap").AddComponent<DemocratMobile>();
    }

    CharacterController controller;
    Transform cameraPivot;
    float yaw, pitch = 12f, gravity;
    string firstName = "Vorname", lastName = "Nachname";
    bool playing;
    Text onlineCountText;

    void Start()
    {
        Application.targetFrameRate = 60;
        Screen.sleepTimeout = SleepTimeout.NeverSleep;
        BuildLighting();

        // The complete authored-by-code government building is now the active world.
        new DemocratGovernmentBuilding().Build();

        ShowCharacterCreation();
    }

    void BuildLighting()
    {
        var sun = new GameObject("Democrat Sun");
        var l = sun.AddComponent<Light>();
        l.type = LightType.Directional;
        l.intensity = 1.15f;
        sun.transform.rotation = Quaternion.Euler(48f, -25f, 0);
        RenderSettings.ambientLight = new Color(.55f, .58f, .62f);
        RenderSettings.fog = true;
        RenderSettings.fogColor = new Color(.48f, .52f, .58f);
        RenderSettings.fogDensity = .003f;
    }

    Material Mat(Color c)
    {
        var m = new Material(Shader.Find("Standard"));
        m.color = c;
        return m;
    }

    Canvas CanvasRoot()
    {
        var go = new GameObject("Mobile UI");
        var c = go.AddComponent<Canvas>();
        c.renderMode = RenderMode.ScreenSpaceOverlay;
        var s = go.AddComponent<CanvasScaler>();
        s.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        s.referenceResolution = new Vector2(1080, 1920);
        go.AddComponent<GraphicRaycaster>();
        return c;
    }

    Text Label(Canvas c, string text, int size, Vector2 anchor, Vector2 pos, Vector2 dims)
    {
        var go = new GameObject("Label");
        go.transform.SetParent(c.transform, false);
        var t = go.AddComponent<Text>();
        t.text = text;
        t.fontSize = size;
        t.color = Color.white;
        t.alignment = TextAnchor.MiddleCenter;

        var r = t.rectTransform;
        r.anchorMin = r.anchorMax = anchor;
        r.pivot = anchor;
        r.anchoredPosition = pos;
        r.sizeDelta = dims;
        return t;
    }

    InputField Field(Canvas c, string placeholder, Vector2 pos)
    {
        var go = new GameObject("Input " + placeholder);
        go.transform.SetParent(c.transform, false);

        var img = go.AddComponent<Image>();
        img.color = new Color(.08f, .09f, .11f, .95f);

        var f = go.AddComponent<InputField>();
        f.textComponent = TextComponent(go, 20);
        f.placeholder = TextComponent(go, 20);
        f.placeholder.text = placeholder;

        var r = go.GetComponent<RectTransform>();
        r.anchorMin = r.anchorMax = new Vector2(.5f, .5f);
        r.pivot = new Vector2(.5f, .5f);
        r.anchoredPosition = pos;
        r.sizeDelta = new Vector2(650, 95);
        return f;
    }

    Text TextComponent(GameObject parent, int size)
    {
        var go = new GameObject("Text");
        go.transform.SetParent(parent.transform, false);
        var t = go.AddComponent<Text>();
        t.fontSize = size;
        t.color = Color.white;
        t.alignment = TextAnchor.MiddleCenter;
        var r = t.rectTransform;
        r.anchorMin = Vector2.zero;
        r.anchorMax = Vector2.one;
        r.offsetMin = new Vector2(25, 0);
        r.offsetMax = new Vector2(-25, 0);
        return t;
    }

    Button Button(Canvas c, string text, Vector2 pos)
    {
        var go = new GameObject("Button " + text);
        go.transform.SetParent(c.transform, false);
        var img = go.AddComponent<Image>();
        img.color = new Color(.12f, .16f, .22f, .98f);
        var b = go.AddComponent<Button>();

        var label = Label(c, text, 30, new Vector2(.5f, .5f), Vector2.zero, new Vector2(650, 95));
        label.transform.SetParent(go.transform, false);
        label.rectTransform.anchorMin = Vector2.zero;
        label.rectTransform.anchorMax = Vector2.one;
        label.rectTransform.anchoredPosition = Vector2.zero;

        var r = go.GetComponent<RectTransform>();
        r.anchorMin = r.anchorMax = new Vector2(.5f, .5f);
        r.pivot = new Vector2(.5f, .5f);
        r.anchoredPosition = pos;
        r.sizeDelta = new Vector2(650, 95);
        return b;
    }

    void ShowCharacterCreation()
    {
        var c = CanvasRoot();

        Label(c, "DEMOCRAT", 64, new Vector2(.5f, .5f),
            new Vector2(0, 650), new Vector2(800, 100));
        Label(c, "CHARAKTER ERSTELLEN", 34, new Vector2(.5f, .5f),
            new Vector2(0, 560), new Vector2(800, 70));

        var first = Field(c, "Vorname", new Vector2(0, 400));
        var last = Field(c, "Nachname", new Vector2(0, 285));
        var b = Button(c, "GEBÄUDE BETRETEN", new Vector2(0, 120));

        b.onClick.AddListener(() =>
        {
            firstName = string.IsNullOrWhiteSpace(first.text) ? "Spieler" : first.text.Trim();
            lastName = string.IsNullOrWhiteSpace(last.text) ? "Donnerfaust" : last.text.Trim();
            Destroy(c.gameObject);
            SpawnPlayer();
        });
    }

    void SpawnPlayer()
    {
        playing = true;

        var go = new GameObject("Player " + firstName + " " + lastName);
        // Entrance hall / public spawn.
        go.transform.position = new Vector3(0, 0.2f, -2f);

        controller = go.AddComponent<CharacterController>();
        controller.height = 1.8f;
        controller.radius = .32f;
        controller.center = Vector3.up * .9f;
        controller.stepOffset = .35f;
        controller.slopeLimit = 45f;

        var playerVisual = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        playerVisual.name = "Player Body";
        playerVisual.transform.SetParent(go.transform, false);
        playerVisual.transform.localPosition = Vector3.up * .9f;
        playerVisual.transform.localScale = new Vector3(.62f, .9f, .62f);
        playerVisual.GetComponent<Renderer>().material = Mat(new Color(.08f, .12f, .18f));
        Destroy(playerVisual.GetComponent<Collider>());

        var head = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        head.name = "Player Head";
        head.transform.SetParent(go.transform, false);
        head.transform.localPosition = new Vector3(0, 1.95f, 0);
        head.transform.localScale = Vector3.one * .42f;
        head.GetComponent<Renderer>().material = Mat(new Color(.78f, .62f, .48f));
        Destroy(head.GetComponent<Collider>());

        cameraPivot = new GameObject("Camera Pivot").transform;
        cameraPivot.SetParent(go.transform, false);
        cameraPivot.localPosition = new Vector3(0, 1.45f, 0);

        var cam = new GameObject("Player Camera");
        cam.tag = "MainCamera";
        var camera = cam.AddComponent<Camera>();
        camera.fieldOfView = 65f;
        cam.AddComponent<AudioListener>();
        cam.transform.SetParent(cameraPivot, false);
        cam.transform.localPosition = new Vector3(0, 1.65f, -5.2f);
        cam.transform.localRotation = Quaternion.Euler(5, 0, 0);

        var ui = CanvasRoot();

        Label(ui, "DEMOCRAT", 34, new Vector2(.5f, 1),
            new Vector2(0, -45), new Vector2(500, 70));

        Label(ui, firstName + " " + lastName + "\nEingangshalle", 24,
            new Vector2(0, 1), new Vector2(25, -35), new Vector2(430, 110));

        Label(ui, "LINKS: BEWEGEN    RECHTS: KAMERA", 20,
            new Vector2(.5f, 0), new Vector2(0, 45), new Vector2(800, 60));

        // GTA-RP-style population display. It currently reports the local prototype player.
        var panel = new GameObject("Online Player Counter");
        panel.transform.SetParent(ui.transform, false);
        var image = panel.AddComponent<Image>();
        image.color = new Color(.025f, .035f, .05f, .88f);

        var rect = panel.GetComponent<RectTransform>();
        rect.anchorMin = new Vector2(1, 1);
        rect.anchorMax = new Vector2(1, 1);
        rect.pivot = new Vector2(1, 1);
        rect.anchoredPosition = new Vector2(-22, -22);
        rect.sizeDelta = new Vector2(190, 62);

        onlineCountText = Label(ui, "●  1 ONLINE", 22,
            new Vector2(1, 1), new Vector2(-38, -52), new Vector2(175, 55));
        onlineCountText.alignment = TextAnchor.MiddleRight;
        UpdateOnlineCount(1);
    }

    void UpdateOnlineCount(int count)
    {
        if (onlineCountText != null)
            onlineCountText.text = "●  " + count.ToString("N0") + " ONLINE";
    }

    void Update()
    {
        if (!playing || controller == null)
            return;

        Vector2 moveInput = Vector2.zero;

        foreach (var t in Input.touches)
        {
            if (t.position.x < Screen.width * .45f)
            {
                moveInput = Vector2.ClampMagnitude(
                    (t.position - new Vector2(Screen.width * .18f, Screen.height * .18f)) /
                    (Screen.height * .12f), 1f);
            }
            else if (t.phase == TouchPhase.Moved)
            {
                yaw += t.deltaPosition.x * .08f;
                pitch = Mathf.Clamp(pitch - t.deltaPosition.y * .06f, -5f, 35f);
            }
        }

        controller.transform.rotation = Quaternion.Euler(0, yaw, 0);

        Vector3 move = controller.transform.forward * moveInput.y +
                       controller.transform.right * moveInput.x;
        if (move.sqrMagnitude > 1)
            move.Normalize();

        if (controller.isGrounded)
            gravity = -1f;
        else
            gravity += Physics.gravity.y * Time.deltaTime;

        move.y = gravity;
        controller.Move(move * 3.8f * Time.deltaTime);
        cameraPivot.localRotation = Quaternion.Euler(pitch, 0, 0);
    }
}
