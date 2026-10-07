export type BrickStatus = "up-next" | "building" | "laid";

export type Brick = {
  id: string;
  title: string;
  description?: string;
  status: BrickStatus;
};

export type Wall = {
  id: string;
  title: string;
  description: string;
  bricks: Brick[];
};

export type Build = {
  id: string;
  title: string;
  description: string;
  walls: Wall[];
};

export const builds: Build[] = [
  {
    id: "healthier-me",
    title: "Build a Healthier Me",
    description: "Build sustainable fitness habits one brick at a time.",
    walls: [
      {
        id: "consistency",
        title: "Build Consistency",
        description: "Create a routine that works in real life.",
        bricks: [
          {
            id: "weekly-plan",
            title: "Choose this week's workouts",
            description: "Pick four realistic workout opportunities.",
            status: "laid"
          },
          {
            id: "peloton",
            title: "Complete a Peloton ride",
            description: "A focused 30-minute ride.",
            status: "building"
          },
          {
            id: "rxfit",
            title: "Get to RXFIT this week",
            description: "Protect the time and show up.",
            status: "up-next"
          }
        ]
      },
      {
        id: "capacity",
        title: "Build Capacity",
        description: "Gradually improve strength and endurance.",
        bricks: [
          {
            id: "baseline",
            title: "Establish a fitness baseline",
            status: "up-next"
          },
          {
            id: "progress",
            title: "Add one small progression",
            status: "up-next"
          }
        ]
      }
    ]
  }
];

export function getBuild(id: string) {
  return builds.find((build) => build.id === id);
}

export function getWall(buildId: string, wallId: string) {
  return getBuild(buildId)?.walls.find((wall) => wall.id === wallId);
}
