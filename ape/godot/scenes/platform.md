# `platform.tscn` — static level geometry

`Platform` (`StaticBody2D`) with a `CollisionShape2D` (`RectangleShape2D`) and two `Polygon2D` children (`Visual` body, `Top` accent strip) for rendering. No script. Scaling the root node scales collision and visuals together — this is the supported way to resize a platform instance, not editing the shape resource per-instance.
