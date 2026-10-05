using UnityEngine;

public sealed class DemocratWorldCapacity : MonoBehaviour
{
    [Header("Logical world capacity")]
    public int logicalPlayerCapacity = 10000;

    [Header("Client-side interest management defaults")]
    public float clientInterestRadius = 55f;
    public int recommendedVisibleRemotePlayers = 80;

    public bool SupportsLogicalPlayerCount(int count)
    {
        return count >= 0 && count <= logicalPlayerCapacity;
    }
}
