#include "DemocratGovernmentBuilding.h"
#include "Components/StaticMeshComponent.h"
#include "UObject/ConstructorHelpers.h"

ADemocratGovernmentBuilding::ADemocratGovernmentBuilding()
{
    PrimaryActorTick.bCanEverTick = false;

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    RootComponent = Root;

    static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
    if (Cube.Succeeded())
        CubeMesh = Cube.Object;
}

void ADemocratGovernmentBuilding::OnConstruction(const FTransform& Transform)
{
    Super::OnConstruction(Transform);

    TArray<USceneComponent*> Children;
    Root->GetChildrenComponents(true, Children);
    for (USceneComponent* Child : Children)
        if (Child) Child->DestroyComponent();

    // Structural shell. Dimensions are centimetres.
    AddRoom(FVector(0, 0, 0), FVector(4200, 3000, 800), TEXT("Entrance Hall"));
    AddRoom(FVector(0, 3900, 0), FVector(4200, 1200, 800), TEXT("Reception"));
    AddRoom(FVector(0, -3900, 0), FVector(4200, 1200, 800), TEXT("Security"));
    AddRoom(FVector(-3000, 0, 0), FVector(1200, 5200, 650), TEXT("Public Corridor West"));
    AddRoom(FVector(3000, 0, 0), FVector(1200, 5200, 650), TEXT("Public Corridor East"));

    AddRoom(FVector(0, 7200, 0), FVector(7000, 4300, 1100), TEXT("Main Plenary"));
    AddRoom(FVector(-5200, 6800, 0), FVector(3000, 2400, 800), TEXT("Large Committee"));
    AddRoom(FVector(5200, 6800, 0), FVector(3000, 2400, 800), TEXT("Medium Committee"));
    AddRoom(FVector(-5200, 3600, 0), FVector(2800, 2100, 800), TEXT("Small Committee"));
    AddRoom(FVector(5200, 3600, 0), FVector(2800, 2100, 800), TEXT("Conference"));
    AddRoom(FVector(0, 4700, 0), FVector(2400, 900, 700), TEXT("Parliamentary Spine"));

    AddRoom(FVector(0, -7000, 0), FVector(5000, 3000, 850), TEXT("Election Hall"));
    AddRoom(FVector(-3400, -6900, 0), FVector(1500, 1800, 750), TEXT("Election Waiting"));
    AddRoom(FVector(3400, -6900, 0), FVector(1500, 1800, 750), TEXT("Election Support"));

    AddRoom(FVector(-6200, -2200, 0), FVector(3000, 2200, 800), TEXT("Faction Area West"));
    AddRoom(FVector(6200, -2200, 0), FVector(3000, 2200, 800), TEXT("Faction Area East"));
    AddRoom(FVector(-6200, 500, 0), FVector(3000, 2000, 800), TEXT("Meeting Rooms West"));
    AddRoom(FVector(6200, 500, 0), FVector(3000, 2000, 800), TEXT("Meeting Rooms East"));

    AddRoom(FVector(-6200, -5600, 0), FVector(3000, 2100, 800), TEXT("Press Center"));
    AddRoom(FVector(6200, -5600, 0), FVector(3000, 2100, 800), TEXT("TV Studio"));
    AddRoom(FVector(0, -5600, 0), FVector(2600, 900, 700), TEXT("Interview Area"));

    AddRoom(FVector(-10500, 1500, 0), FVector(2400, 7000, 700), TEXT("Office Wing West"));
    AddRoom(FVector(10500, 1500, 0), FVector(2400, 7000, 700), TEXT("Office Wing East"));

    AddRoom(FVector(-9000, -3000, 0), FVector(1800, 1600, 700), TEXT("Security Room"));
    AddRoom(FVector(9000, -3000, 0), FVector(1800, 1600, 700), TEXT("Technical Room"));
    AddRoom(FVector(-9000, -5200, 0), FVector(1800, 1400, 700), TEXT("Storage West"));
    AddRoom(FVector(9000, -5200, 0), FVector(1800, 1400, 700), TEXT("Storage East"));

    // Architectural circulation and vertical cores.
    AddStaircase(FVector(-1600, 0, 0), TEXT("Staircase_West"));
    AddElevator(FVector(1600, 0, 0), TEXT("Elevator_East"));
    AddStaircase(FVector(0, 5600, 0), TEXT("Staircase_Parliament"));

    // Major entrance doors and interior transitions.
    AddDoor(FVector(0, 1550, 0), TEXT("Entrance_MainDoor"));
    AddDoor(FVector(0, -1550, 0), TEXT("Entrance_SecurityDoor"));
    AddDoor(FVector(0, 4500, 0), TEXT("Reception_ParliamentDoor"));
    AddDoor(FVector(0, -5400, 0), TEXT("Interview_ElectionDoor"));

    // Large facade glazing. These are structural window modules now;
    // final glass materials can be assigned in the Unreal Editor.
    AddWindow(FVector(-2100, 0, 400), FVector(40, 2200, 650), TEXT("Entrance_Glass_West"));
    AddWindow(FVector(2100, 0, 400), FVector(40, 2200, 650), TEXT("Entrance_Glass_East"));
    AddWindow(FVector(0, 1500, 500), FVector(2600, 40, 600), TEXT("Entrance_Glass_North"));
    AddWindow(FVector(0, -1500, 500), FVector(2600, 40, 600), TEXT("Entrance_Glass_South"));

    // High ceiling markers create the intended architectural volume.
    AddCeiling(FVector(0, 0, 780), FVector(4200, 3000, 20), TEXT("Entrance_Ceiling"));
    AddCeiling(FVector(0, 7200, 1080), FVector(7000, 4300, 20), TEXT("Plenary_Ceiling"));
}

void ADemocratGovernmentBuilding::AddBlock(const FVector& Location, const FVector& Scale, const FString& Label)
{
    if (!CubeMesh) return;

    UStaticMeshComponent* Mesh = NewObject<UStaticMeshComponent>(this);
    Mesh->RegisterComponent();
    Mesh->SetStaticMesh(CubeMesh);
    Mesh->SetCollisionProfileName(TEXT("BlockAll"));
    Mesh->SetWorldLocation(GetActorLocation() + Location);
    Mesh->SetWorldScale3D(Scale);
    Mesh->AttachToComponent(Root, FAttachmentTransformRules::KeepWorldTransform);
    Mesh->ComponentTags.Add(FName(*Label));
}

void ADemocratGovernmentBuilding::AddRoom(const FVector& Center, const FVector& Size, const FString& Label)
{
    const float X = Size.X;
    const float Y = Size.Y;
    const float Wall = 25.0f;
    const float Height = Size.Z;

    AddBlock(Center + FVector(0, 0, -50), FVector(X / 100.0f, Y / 100.0f, 0.5f), Label + TEXT("_Floor"));

    AddWallWithDoor(Center + FVector(0, Y / 2.0f, 0), FVector(X, Wall, Height), true, Label + TEXT("_North"));
    AddWallWithDoor(Center + FVector(0, -Y / 2.0f, 0), FVector(X, Wall, Height), true, Label + TEXT("_South"));
    AddWallWithDoor(Center + FVector(X / 2.0f, 0, 0), FVector(Wall, Y, Height), false, Label + TEXT("_East"));
    AddWallWithDoor(Center + FVector(-X / 2.0f, 0, 0), FVector(Wall, Y, Height), false, Label + TEXT("_West"));

    // A ceiling is generated for normal rooms. High-volume rooms may replace it
    // later with a bespoke architectural ceiling in the editor.
    if (Height <= 850.0f)
        AddCeiling(Center + FVector(0, 0, Height), FVector(X, Y, 20), Label + TEXT("_Ceiling"));
}

void ADemocratGovernmentBuilding::AddWallWithDoor(const FVector& Center, const FVector& Size, bool bHorizontal, const FString& Label)
{
    const float DoorWidth = 180.0f;
    const float DoorHeight = 230.0f;
    const float WallThickness = bHorizontal ? Size.Y : Size.X;
    const float Length = bHorizontal ? Size.X : Size.Y;

    // Leave a real passage in the wall by building three segments around it.
    const float SideLength = FMath::Max(0.0f, (Length - DoorWidth) * 0.5f);
    const float Half = Length * 0.5f;

    if (bHorizontal)
    {
        AddBlock(Center + FVector(-(Half - SideLength * 0.5f), 0, Size.Z * 0.5f),
            FVector(SideLength / 100.0f, WallThickness / 100.0f, Size.Z / 100.0f), Label + TEXT("_Left"));
        AddBlock(Center + FVector((Half - SideLength * 0.5f), 0, Size.Z * 0.5f),
            FVector(SideLength / 100.0f, WallThickness / 100.0f, Size.Z / 100.0f), Label + TEXT("_Right"));
        const float HeaderHeight = FMath::Max(0.0f, Size.Z - DoorHeight);
        AddBlock(Center + FVector(0, 0, DoorHeight + HeaderHeight * 0.5f),
            FVector(DoorWidth / 100.0f, WallThickness / 100.0f, HeaderHeight / 100.0f),
            Label + TEXT("_Header"));
    }
    else
    {
        AddBlock(Center + FVector(0, -(Half - SideLength * 0.5f), Size.Z * 0.5f),
            FVector(WallThickness / 100.0f, SideLength / 100.0f, Size.Z / 100.0f), Label + TEXT("_Left"));
        AddBlock(Center + FVector(0, (Half - SideLength * 0.5f), Size.Z * 0.5f),
            FVector(WallThickness / 100.0f, SideLength / 100.0f, Size.Z / 100.0f), Label + TEXT("_Right"));
        const float HeaderHeight = FMath::Max(0.0f, Size.Z - DoorHeight);
        AddBlock(Center + FVector(0, 0, DoorHeight + HeaderHeight * 0.5f),
            FVector(WallThickness / 100.0f, DoorWidth / 100.0f, HeaderHeight / 100.0f),
            Label + TEXT("_Header"));
    }
}

void ADemocratGovernmentBuilding::AddDoor(const FVector& Location, const FString& Label)
{
    // Door leaf + frame placeholder. The opening itself is produced by the wall module.
    AddBlock(Location + FVector(0, 0, 115), FVector(0.9f, 0.08f, 2.3f), Label + TEXT("_Leaf"));
    AddBlock(Location + FVector(-45, 0, 115), FVector(0.08f, 0.14f, 2.45f), Label + TEXT("_Frame_L"));
    AddBlock(Location + FVector(45, 0, 115), FVector(0.08f, 0.14f, 2.45f), Label + TEXT("_Frame_R"));
}

void ADemocratGovernmentBuilding::AddWindow(const FVector& Location, const FVector& Size, const FString& Label)
{
    // Thin structural placeholder for future glass/material assignment.
    AddBlock(Location, FVector(Size.X / 100.0f, Size.Y / 100.0f, Size.Z / 100.0f), Label);
}

void ADemocratGovernmentBuilding::AddStaircase(const FVector& Location, const FString& Label)
{
    // Ten-step architectural placeholder, each step offset in X/Y.
    constexpr int32 Steps = 10;
    constexpr float StepWidth = 300.0f;
    constexpr float StepDepth = 35.0f;
    constexpr float StepHeight = 18.0f;

    for (int32 i = 0; i < Steps; ++i)
    {
        AddBlock(Location + FVector(i * StepDepth, 0, i * StepHeight),
            FVector(StepDepth / 100.0f, StepWidth / 100.0f, StepHeight / 100.0f),
            FString::Printf(TEXT("%s_Step_%02d"), *Label, i + 1));
    }

    AddBlock(Location + FVector(Steps * StepDepth * 0.5f, 0, Steps * StepHeight + 90),
        FVector((Steps * StepDepth) / 100.0f, 3.5f, 1.8f), Label + TEXT("_Landing"));
}

void ADemocratGovernmentBuilding::AddElevator(const FVector& Location, const FString& Label)
{
    AddBlock(Location + FVector(0, 0, 120), FVector(1.6f, 1.6f, 2.4f), Label + TEXT("_Cabin"));
    AddBlock(Location + FVector(0, 82, 120), FVector(1.8f, 0.08f, 2.5f), Label + TEXT("_FrontFrame"));
}

void ADemocratGovernmentBuilding::AddCeiling(const FVector& Center, const FVector& Size, const FString& Label)
{
    AddBlock(Center, FVector(Size.X / 100.0f, Size.Y / 100.0f, Size.Z / 100.0f), Label);
}
