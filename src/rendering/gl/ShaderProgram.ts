import {vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;
  //attrNor;

  unifView: WebGLUniformLocation;
  unifWidth: WebGLUniformLocation;
  unifHeight: WebGLUniformLocation;
  unifEye: WebGLUniformLocation;
  unifModel: WebGLUniformLocation;
  unifModelInv: WebGLUniformLocation;
  unifModelInvTr: WebGLUniformLocation;
  unifViewProj: WebGLUniformLocation;
  unifViewProjInv: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;


  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    // Raymarcher only draws a quad in screen space! No other attributes
    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");

    // TODO: add other attributes here
    this.unifView   = gl.getUniformLocation(this.prog, "u_View");
    this.unifWidth  = gl.getUniformLocation(this.prog, "u_Width");
    this.unifHeight   = gl.getUniformLocation(this.prog, "u_Height");
    this.unifEye  = gl.getUniformLocation(this.prog, "u_Eye");
    this.unifModel      = gl.getUniformLocation(this.prog, "u_Model");
    this.unifModelInv      = gl.getUniformLocation(this.prog, "u_ModelInv");
    this.unifModelInvTr = gl.getUniformLocation(this.prog, "u_ModelInvTr");
    this.unifViewProj   = gl.getUniformLocation(this.prog, "u_ViewProj");
    this.unifViewProjInv   = gl.getUniformLocation(this.prog, "u_ViewProjInv");
    this.unifTime       = gl.getUniformLocation(this.prog, "u_Time");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  // TODO: add functions to modify uniforms

  setWidth(w: number) {
    this.use();
    if(this.unifWidth != -1) {
      gl.uniform1f(this.unifWidth, w);
    }
  }

  setHeight(h: number) {
    this.use();
    if(this.unifHeight != -1) {
      gl.uniform1f(this.unifHeight, h);
    }
  }

  setEye(e: vec4) {
    this.use();
    if(this.unifEye != -1) {
      gl.uniform4fv(this.unifEye, e);
    }
  }

  setModelMatrix(model: mat4) {
    this.use();
    if (this.unifModel !== -1) {
      gl.uniformMatrix4fv(this.unifModel, false, model);
    }

    if (this.unifModelInv !== -1) {
      let modelinv: mat4 = mat4.create();
      mat4.invert(modelinv, model);
      gl.uniformMatrix4fv(this.unifModelInv, false, modelinv);
    }

    if (this.unifModelInvTr !== -1) {
      let modelinvtr: mat4 = mat4.create();
      mat4.transpose(modelinvtr, model);
      mat4.invert(modelinvtr, modelinvtr);
      gl.uniformMatrix4fv(this.unifModelInvTr, false, modelinvtr);
    }
  }

  setViewProjMatrix(vp: mat4) {
    this.use();
    if (this.unifViewProj !== -1) {
      gl.uniformMatrix4fv(this.unifViewProj, false, vp);
    }
    if (this.unifViewProjInv !== -1) {
      let vpinv: mat4 = mat4.create();
      mat4.invert(vpinv, vp);
      gl.uniformMatrix4fv(this.unifViewProjInv, false, vpinv);
    }
  }

 setTime(t: number) {
    this.use();
    if(this.unifTime != -1) {
        gl.uniform1f(this.unifTime, t);
    }
}


  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);

  }
};

export default ShaderProgram;
