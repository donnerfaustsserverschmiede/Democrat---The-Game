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

    // Democrat Government Complex
    // Units are centimetres. The layout is deliberately original and avoids
    // official German government symbols or a 1:1 reproduction of any real building.

    // Public entrance / central circulation spine.
    AddRoom(FVector(0, 0, 0), FVector(4200, 3000, 800), TEXT("Entrance Hall"));
    AddRoom(FVector(0, 3900, 0), FVector(4200, 1200, 800), TEXT("Reception"));
    AddRoom(FVector(0, -3900, 0), FVector(4200, 1200, 800), TEXT("Security"));
    AddRoom(FVector(-3000, 0, 0), FVector(1200, 5200, 650), TEXT("Public Corridor West"));
    AddRoom(FVector(3000, 0, 0), FVector(1200, 5200, 650), TEXT("Public Corridor East"));

    // Parliamentary core. The central corridor keeps the building connected.
    AddRoom(FVector(0, 7200, 0), FVector(7000, 4300, 1100), TEXT("Main Plenary"));
    AddRoom(FVector(-5200, 6800, 0), FVector(3000, 2400, 800), TEXT("Large Committee"));
    AddRoom(FVector(5200, 6800, 0), FVector(3000, 2400, 800), TEXT("Medium Committee"));
    AddRoom(FVector(-5200, 3600, 0), FVector(2800, 2100, 800), TEXT("Small Committee"));
    AddRoom(FVector(5200, 3600, 0), FVector(2800, 2100, 800), TEXT("Conference"));
    AddRoom(FVector(0, 4700, 0), FVector(2400, 900, 700), TEXT("Parliamentary Spine"));

    // Election wing: permanently present in the architecture, mechanics can arrive later.
    AddRoom(FVector(0, -7000, 0), FVector(5000, 3000, 850), TEXT("Election Hall"));
    AddRoom(FVector(-3400, -6900, 0), FVector(1500, 1800, 750), TEXT("Election Waiting"));
    AddRoom(FVector(3400, -6900, 0), FVector(1500, 1800, 750), TEXT("Election Support"));

    // Political/faction wing.
    AddRoom(FVector(-6200, -2200, 0), FVector(3000, 2200, 800), TEXT("Faction Area West"));
    AddRoom(FVector(6200, -2200, 0), FVector(3000, 2200, 800), TEXT("Faction Area East"));
    AddRoom(FVector(-6200, 500, 0), FVector(3000, 2000, 800), TEXT("Meeting Rooms West"));
    AddRoom(FVector(6200, 500, 0), FVector(3000, 2000, 800), TEXT("Meeting Rooms East"));

    // Media wing.
    AddRoom(FVector(-6200, -5600, 0), FVector(3000, 2100, 800), TEXT("Press Center"));
    AddRoom(FVector(6200, -5600, 0), FVector(3000, 2100, 800), TEXT("TV Studio"));
    AddRoom(FVector(0, -5600, 0), FVector(2600, 900, 700), TEXT("Interview Area"));

    // Future-ready office wings.
    AddRoom(FVector(-10500, 1500, 0), FVector(2400, 7000, 700), TEXT("Office Wing West"));
    AddRoom(FVector(10500, 1500, 0), FVector(2400, 7000, 700), TEXT("Office Wing East"));

    // Infrastructure / service rooms.
    AddRoom(FVector(-9000, -3000, 0), FVector(1800, 1600, 700), TEXT("Security Room"));
    AddRoom(FVector(9000, -3000, 0), FVector(1800, 1600, 700), TEXT("Technical Room"));
    AddRoom(FVector(-9000, -5200, 0), FVector(1800, 1400, 700), TEXT("Storage West"));
    AddRoom(FVector(9000, -5200, 0), FVector(1800, 1400, 700), TEXT("Storage East"));

    // Vertical circulation markers: these become actual stair/elevator assets later.
    AddBlock(FVector(-1600, 0, 120), FVector(7.0f, 7.0f, 2.4f), TEXT("Staircase_West"));
    AddBlock(FVector(1600, 0, 120), FVector(7.0f, 7.0f, 2.4f), TEXT("Elevator_East"));
    AddBlock(FVector(0, 5600, 120), FVector(7.0f, 7.0f, 2.4f), TEXT("Staircase_Parliament"));
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

    // Floor.
    AddBlock(Center + FVector(0, 0, -50), FVector(X / 100.0f, Y / 100.0f, 0.5f), Label + TEXT("_Floor"));

    // Wall shell. Doors/openings are represented by separate architectural
    // modules in the next pass so the floorplan stays reusable.
    AddBlock(Center + FVector(0, Y / 2.0f, Height / 2.0f), FVector(X / 100.0f, Wall / 100.0f, Height / 100.0f), Label + TEXT("_North"));
    AddBlock(Center + FVector(0, -Y / 2.0f, Height / 2.0f), FVector(X / 100.0f, Wall / 100.0f, Height / 100.0f), Label + TEXT("_South"));
    AddBlock(Center + FVector(X / 2.0f, 0, Height / 2.0f), FVector(Wall / 100.0f, Y / 100.0f, Height / 100.0f), Label + TEXT("_East"));
    AddBlock(Center + FVector(-X / 2.0f, 0, Height / 2.0f), FVector(Wall / 100.0f, Y / 100.0f, Height / 100.0f), Label + TEXT("_West"));
}
