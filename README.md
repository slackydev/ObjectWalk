Reawakening of ObjectDTM walking!?
=================================

Basically this is a tool for walking, and positioning. It doesn't use a big ass image like RSWalker but instead 
some userdefined "feature points", and locates a relative position to these points, and then it can walk based on those.
the feature points are based on trees, rocks and similar stuff found on the minimap.

Check out the `test.simba` file to try it in action. 


There is currently no utility for making paths, so that's gonna be a real bitch if you try to make your own path.

I have tried to keep the points as easy as possible - All points are just grabed streight off the minimap, 
but note that you gotta get them all at once, fairly "quickly", as the minimap will deform overtime, and we do not want that, 
as each point should relate to how the minimap is with the current deformities/transformations.


---------------------------------

Note: This is not based on the original ObjectDTM, but fully recreated.

