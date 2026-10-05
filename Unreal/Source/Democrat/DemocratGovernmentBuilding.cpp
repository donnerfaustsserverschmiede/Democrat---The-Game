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

    // Overall footprint: a large, modern parliamentary government complex.
    // All dimensions are centimeters.

    // Main entrance hall / spawn.
    AddRoom(FVector(0, 0, 0), FVector(3600, 2600, 600), TEXT("Entrance Hall"));
    AddRoom(FVector(0, 3300, 0), FVector(3600, 1800, 600), TEXT("Reception"));
    AddRoom(FVector(0, -3300, 0), FVector(3600, 1800, 600), TEXT("Security"));

    // Parliamentary core.
    AddRoom(FVector(0, 7000, 0), FVector(5200, 4200, 800), TEXT("Main Plenary"));
    AddRoom(FVector(-6500, 7000, 0), FVector(3000, 2400, 700), TEXT("Large Committee"));
    AddRoom(FVector(6500, 7000, 0), FVector(3000, 2400, 700), TEXT("Medium Committee"));
    AddRoom(FVector(-6500, 3600, 0), FVector(2600, 2000, 650), TEXT("Small Committee"));
    AddRoom(FVector(6500, 3600, 0), FVector(2600, 2000, 650), TEXT("Conference"));

    // Election wing.
    AddRoom(FVector(0, -6500, 0), FVector(4200, 3000, 650), TEXT("Election Hall"));

    // Political / media wings.
    AddRoom(FVector(-6200, -2500, 0), FVector(3000, 2200, 650), TEXT("Faction Area A"));
    AddRoom(FVector(6200, -2500, 0), FVector(3000, 2200, 650), TEXT("Faction Area B"));
    AddRoom(FVector(-6200, -6200, 0), FVector(3000, 2000, 650), TEXT("Press Center"));
    AddRoom(FVector(6200, -6200, 0), FVector(3000, 2000, 650), TEXT("TV Studio"));

    // Future-ready office wings.
    AddRoom(FVector(-10500, 1000, 0), FVector(2400, 5200, 600), TEXT("Office Wing West"));
    AddRoom(FVector(10500, 1000, 0), FVector(2400, 5200, 600), TEXT("Office Wing East"));
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

    // Four walls; openings are intentionally left for future doors.
    AddBlock(Center + FVector(0, Y / 2.0f, Height / 2.0f), FVector(X / 100.0f, Wall / 100.0f, Height / 100.0f), Label + TEXT("_North"));
    AddBlock(Center + FVector(0, -Y / 2.0f, Height / 2.0f), FVector(X / 100.0f, Wall / 100.0f, Height / 100.0f), Label + TEXT("_South"));
    AddBlock(Center + FVector(X / 2.0f, 0, Height / 2.0f), FVector(Wall / 100.0f, Y / 100.0f, Height / 100.0f), Label + TEXT("_East"));
    AddBlock(Center + FVector(-X / 2.0f, 0, Height / 2.0f), FVector(Wall / 100.0f, Y / 100.0f, Height / 100.0f), Label + TEXT("_West"));
}