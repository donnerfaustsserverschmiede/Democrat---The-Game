using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

[InitializeOnLoad]
public static class DemocratProjectSetup
{
    const string ScenePath = "Assets/Scenes/DemocratMain.unity";

    static DemocratProjectSetup()
    {
        EditorApplication.delayCall += Setup;
    }

    static void Setup()
    {
        if (Application.isPlaying) return;

        Directory.CreateDirectory("Assets/Scenes");

        if (!File.Exists(ScenePath))
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var bootstrap = new GameObject("Democrat Mobile Bootstrap");
            bootstrap.AddComponent<DemocratMobile>();
            EditorSceneManager.SaveScene(scene, ScenePath);
        }

        var scenes = new System.Collections.Generic.List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
        bool found = false;

        foreach (var scene in scenes)
        {
            if (scene.path == ScenePath)
            {
                scene.enabled = true;
                found = true;
            }
        }

        if (!found)
            scenes.Insert(0, new EditorBuildSettingsScene(ScenePath, true));

        EditorBuildSettings.scenes = scenes.ToArray();
    }
}
