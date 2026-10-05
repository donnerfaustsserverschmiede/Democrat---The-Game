#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class DemocratWebGLBuild
{
    public static void BuildWebGL()
    {
        const string output = "Build/WebGL";
        Directory.CreateDirectory(output);

        var options = new BuildPlayerOptions
        {
            scenes = new[] { "Assets/Scenes/DemocratMain.unity" },
            locationPathName = output,
            target = BuildTarget.WebGL,
            options = BuildOptions.None
        };

        var report = BuildPipeline.BuildPlayer(options);

        if (report.summary.result != BuildResult.Succeeded)
            throw new System.Exception("Democrat WebGL build failed: " + report.summary.result);
        
        Debug.Log("Democrat WebGL build succeeded: " + report.summary.totalSize + " bytes");
    }
}
#endif
