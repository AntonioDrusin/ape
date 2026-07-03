# `wall.tscn` — level boundary

`Wall` (`StaticBody2D`) with a `CollisionShape2D` (`RectangleShape2D`) and a single `Polygon2D` (`Visual`), same base size as `platform.tscn` but a flat stone color and no grass `Top` strip — unlike ground, a boundary wall is seen edge-on and rotated, so a grass accent wouldn't read correctly. Same scale-to-resize convention as `platform.tscn`.
