#version 300 es

#define PI 3.1459265

precision highp float;
in vec4 fs_Pos;           


uniform vec4 u_Eye;
uniform mat4 u_Model;
uniform mat4 u_ModelInv;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform mat4 u_ViewProjInv;
uniform float u_Time;
uniform float u_Width;
uniform float u_Height;


const vec4 lightPos = vec4(0, 5, 5, 1); //The position of our virtual light, which is used to compute the shading of
 
out vec4 out_Col;

mat4 rotate(vec3 rot) {
	mat4 rx = mat4(vec4(1, 0, 0, 0),
					vec4(0, cos(rot.x * PI/180.f), sin(rot.x * PI/180.f), 0),
					vec4(0, -sin(rot.x * PI/180.f), cos(rot.x * PI/180.f), 0),
					vec4(0, 0, 0, 1));
	mat4 ry = mat4(vec4(cos(rot.y * PI/180.f), 0, -sin(rot.y * PI/180.f), 0),
					vec4(0, 1, 0, 0),
					vec4(sin(rot.y * PI/180.f), 0, cos(rot.y * PI/180.f), 0),
					vec4(0, 0, 0, 1));
	mat4 rz = mat4(vec4(cos(rot.z * PI/180.f), sin(rot.z * PI/180.f), 0, 0),
					vec4(-sin(rot.z * PI/180.f), cos(rot.z * PI/180.f), 0, 0),
					vec4(0, 0, 1, 0),
					vec4(0, 0, 0, 1));
					
	return rz * ry * rx;
	
}

mat4 translate(vec3 trans) {
	return mat4(vec4(1, 0, 0, 0),
				vec4(0, 1, 0, 0),
				vec4(0, 0, 1, 0),
				vec4(trans.x, trans.y, trans.z, 1));
}


// the SDFs below are from http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdTriPrism(vec4 p, vec2 h, vec3 trans, vec3 rot)
{
	p = rotate(rot) * translate(trans) * p;
    vec4 q = abs(p);
    return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

float sphereSDF(vec4 intersection, float radius, vec3 trans, vec3 rot) {
	return (length(rotate(rot) * translate(trans) * intersection)-radius);
}


float sdCappedCylinder(vec4 p, vec2 h , vec3 trans, vec3 rot)
{
	p = rotate(rot) * translate(trans) * p;
  	vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdBox(vec4 p, vec4 b, vec3 trans, vec3 rot) {
	p = rotate(rot) * translate(trans) * p;
  	vec4 d = abs(p)  - b;
  	return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

//these 3 functions are from http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#constructive-solid-geometry
float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}

float unionSDF(float distA, float distB) {
    return min(distA, distB);
}

float differenceSDF(float distA, float distB) {
    return max(distA, -distB);
}

float sceneSDF(vec4 intersection) {
	float eyeL = sdCappedCylinder(intersection, vec2(.4, .5), vec3(.5, -2, 0), vec3(90, -10, 0));
	float eyeR = sdCappedCylinder(intersection, vec2(.4, .5), vec3(-.5, -2, 0), vec3(90, 10, 0));
	float eyeInsideL = sphereSDF(intersection, 1.f, vec3(.3, -2, -.5), vec3(0, 0, 0));
	float eyeInsideR = sphereSDF(intersection, 1.f, vec3(-.3, -2, -.5), vec3(0, 0, 0));
	eyeR = unionSDF(eyeR, eyeInsideR);
	eyeL = unionSDF(eyeL, eyeInsideL);
	float eyes = unionSDF(eyeL, eyeR);

	float neck = sdBox(intersection, vec4(.2, 1, .2, 1), vec3(0, -1, 0), vec3(0, 0, 0));
	neck = unionSDF(neck, eyes);

	float body = sdBox(intersection, vec4(1, 1, 1, 1), vec3(0, 0, 0), vec3(0, 0, 0));
	
	float legL = sdTriPrism(intersection, vec2(1.2, .4), vec3(1.2, 1.5, 0), vec3(0, 90, 0));
	float legR = sdTriPrism(intersection, vec2(1.2, .4), vec3(-1.2, 1.5, 0), vec3(0, 90, 0));
	float legs = unionSDF(legL, legR);

	float armRUpper = sdCappedCylinder(intersection, vec2(.2, .2), vec3(-1.1, -.3, 0), vec3(0, -10, 0));
	float armR = sdCappedCylinder(intersection, vec2(.2, 1), vec3(-1.4, -.3, -.8), vec3(90, -10, 0));
	float armLUpper = sdCappedCylinder(intersection, vec2(.2, .2), vec3(1.1, -.3, 0), vec3(0, -10, 0));
	float armL = sdCappedCylinder(intersection, vec2(.2, 1), vec3(1.4, -.3, -.8), vec3(90, -10, 0));
	
	
	armL = unionSDF(armL, armLUpper);
	armR = unionSDF(armR, armRUpper);
	float arms = unionSDF(armL, armR);
	body = unionSDF(body, arms);
	body = unionSDF(body, legs);
	return unionSDF(body, neck);
}

// this function to calculate the normals is from http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#constructive-solid-geometry
vec4 estimateNormal(vec4 p) {
	float EPSILON = .001f;
    return normalize(vec4(
        sceneSDF(vec4(p.x + EPSILON, p.y, p.z, 1.f)) - sceneSDF(vec4(p.x - EPSILON, p.y, p.z, 1.f)),
        sceneSDF(vec4(p.x, p.y + EPSILON, p.z, 1.f)) - sceneSDF(vec4(p.x, p.y - EPSILON, p.z, 1.f)),
        sceneSDF(vec4(p.x, p.y, p.z  + EPSILON, 1.f)) - sceneSDF(vec4(p.x, p.y, p.z - EPSILON, 1.f)), 0
    ));
}

vec4 lambert(vec4 p, vec4 diffuseColor) {
	vec4 normal = estimateNormal(p);
	float diffuseTerm = dot(normalize(normal), normalize(lightPos - p));
	clamp(diffuseTerm, 0.f, 1.f);
	return vec4(diffuseColor.rgb * (diffuseTerm + .2), 1.f);	
}

vec4 gradient(vec4 p, vec4 diffuseColor) {
	vec4 normal = estimateNormal(p);
	float t = dot(normalize(normal), normalize(lightPos - p));
    // Avoid negative lighting values
    t = clamp(t, 0.f, 1.f);

    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1, 1, 1);
    vec3 d = vec3(0.0, 0.33, 0.67);


    return vec4(a + b * cos(2.0f * PI * (c * t + d)), 1);
}


void main() {
	float radius = 2.0;

	vec4 eye =  vec4(5.0 * sin(0.001 *u_Time), 0, 5.0 * cos(0.001 * u_Time), 1.0);
	float fov = 75.f;
	vec4 ref = vec4(0.0, 0.0, 0.0, 1.0);

	float sx = (fs_Pos.x);
    float sy = (fs_Pos.y);
    float alpha = fov / 2.f * (PI / 180.f);
    vec4 forward = normalize(ref - eye);
   	vec4 right = normalize(vec4(cross(vec3(0, 1, 0), vec3(forward)), 0));
   	vec4 localUp = normalize(vec4(cross(vec3(forward), vec3(right)), 0));
    float A = u_Width / u_Height;

    //convert screen point to world point
    float len = 0.1;
    vec4 V = (localUp * len * tan(alpha));
    vec4 H = right * len * A * tan(alpha);

    vec4 p = eye + len * forward + sx * H + sy * V; //world point 

    //get ray from world point
    vec4 dir = normalize(p - eye);
    vec4 origin = eye;

	vec4 intersection;
	bool intersected = false;
	vec4 diffuseColor;


	vec4 minInter;
	float wallE;
	float t = 0.01;
	for (int i = 0; i < 64; i++) {
		intersection = origin + dir * t;
		wallE = sceneSDF(intersection);
		
		if(wallE < .01) {
			intersected = true;
			minInter = intersection;
			break;
		}
		t += wallE;
	}
	if (intersected) {
		diffuseColor = vec4(1, 1, 0, 1);
		out_Col = gradient(translate(vec3(0, 0, 0)) * minInter, diffuseColor);
	}

	if(!intersected) {
		diffuseColor = mix((fs_Pos + vec4(1.f))/ 2.f, vec4(0, 0, 0, 1), cos(u_Time * .01));//mix(vec4(1, 0, 1, 1), vec4(0, 1, 1, 1), cos(u_Time * .01)); //vec4(wallE, 0, 1, 1);
		out_Col = diffuseColor;//vec4(0.f, 0, 0, 1);

	}
}
