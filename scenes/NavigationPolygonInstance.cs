using Godot;
using System;

public class NavigationPolygonInstance : Godot.NavigationPolygonInstance
{
	// Declare member variables here. Examples:
	// private int a = 2;
	// private string b = "text";

	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{

		Polygon2D polygon2D = GetNode<Polygon2D>("Polygon2D");
		

		NavigationPolygonInstance navInstance = GetNode<NavigationPolygonInstance>(".");
		
		if (polygon2D != null && navInstance != null)
		{

			NavigationPolygon navPoly = new NavigationPolygon();
			

			Vector2[] vertices = polygon2D.Polygon;
			navPoly.Vertices = vertices;
			

			int[] indices = new int[vertices.Length];
			for (int i = 0; i < vertices.Length; i++)
				indices[i] = i;
			navPoly.AddPolygon(indices);
			

			navInstance.Navpoly = navPoly;
			

			polygon2D.Visible = false;
			

		}
	}

//  // Called every frame. 'delta' is the elapsed time since the previous frame.
//  public override void _Process(float delta)
//  {
//      
//  }
}
