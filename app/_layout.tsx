import { Stack } from "expo-router";
import { theme } from "../src/theme";

export default function RootLayout() {
  return (
    <Stack
      screenOptions={{
        headerStyle: { backgroundColor: theme.background },
        headerShadowVisible: false,
        headerTintColor: theme.ink,
        contentStyle: { backgroundColor: theme.background },
      }}
    >
      <Stack.Screen name="index" options={{ title: "Brick by Brick" }} />
      <Stack.Screen name="build/[buildId]" options={{ title: "Build" }} />
      <Stack.Screen name="wall/[buildId]/[wallId]" options={{ title: "Wall" }} />
    </Stack>
  );
}
