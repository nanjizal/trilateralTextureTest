package;
#if (haxe_ver < 4.0 )
import js.html.Float32Array;
#else
import  js.lib.Float32Array;
#end
import js.html.CanvasElement;
import js.html.webgl.RenderingContext;
import js.html.webgl.Program;
import js.html.webgl.Shader;
import js.Browser;
import js.html.Uint16Array;
import htmlHelper.tools.ImageLoader;
import js.html.StyleElement;
import js.html.ImageElement;
import js.html.Image;
import HaxeLogo;
import geom.matrix.Matrix4x3;
import trilateral.tri.*;
import trilateral.geom.*;
import trilateral.path.*;
import trilateral.justPath.*;
import trilateral.angle.*;
import trilateral.polys.*;
import trilateral.angle.*;
import trilateralXtra.color.AppColors;
import trilateral.polys.Shapes;
import trilateral.justPath.transform.ScaleContext;
import trilateral.justPath.transform.ScaleTranslateContext;
import trilateral.justPath.transform.TranslationContext;
import htmlHelper.tools.AnimateTimer;
using Test;
class Test {
    public static inline var vertexString: String =
        'attribute vec3 pos;' +
        'attribute vec2 aTexture;' +
        'varying vec2 texture;' +
        'uniform mat4 modelViewProjection;' +
        'void main(void) {' + 
            ' gl_Position = modelViewProjection * vec4( pos, 1.0);' +
            ' texture = vec2( aTexture.x , 1.-aTexture.y );' +
        '}';
    
    public static inline var fragmentString: String =
        'precision mediump float;' +
        'uniform sampler2D image;' +
        'varying vec2 texture;' +
        'void main(void) {' +
            'float bound =   step( texture.s, 1. ) *' +
                            'step( texture.t, 1. ) *' +
                            ' ( 1. - step( texture.s, 0. ) ) * '+
                            ' ( 1. - step( texture.t, 0. ) );'+
            'gl_FragColor = bound * texture2D( image, vec2( texture.s, texture.t ) );'+
        '}'; 
    
    public static inline function ident(): Array<Float> {
        return [ 1.0, 0.0, 0.0, 0.0,
                 0.0, 1.1, 0.0, 0.0,
                 0.0, 0.0, 1.0, 0.0,
                 0.0, 0.0, 0.0, 1.0
                 ];
    }
    static function main(){ new Test(); }
    public var appColors:       Array<AppColors> = [ Black, Red, Orange, Yellow, Green, Blue, Indigo, Violet
                                                   , LightGrey, MidGrey, DarkGrey, NearlyBlack, White
                                                   , BlueAlpha, GreenAlpha, RedAlpha ];
    public static inline var width: Int = 800;
    public static inline var height: Int = 800;
    public var triangles:       TriangleArray;
    var canvas: CanvasElement;
    var gl: RenderingContext;
    var program: Program;
    var imageLoader: ImageLoader;
    var vertices = new Array<Float>();
    var texturePos = new Array<Float>();
    var indices = new Array<Int>();
    var scale:                  Float;
    var theta = 0.0; // Angle in radians
    var modelViewProjection = Matrix4x3.unit; // external matrix controlling global 3d position
    var matrix32Array = new haxe.io.Float32Array( 16 );//ident() ); // internal matrix passed to shader
    
    public function new(){
        var arr = matrix32Array;
        arr[ 0 ]  = 1.; arr[ 1 ]  = 0.; arr[ 2 ]  = 0.; arr[ 3 ]  = 0.;
        arr[ 4 ]  = 0.; arr[ 5 ]  = 1.; arr[ 6 ]  = 0.; arr[ 7 ]  = 0.;
        arr[ 8 ]  = 0.; arr[ 9 ]  = 0.; arr[ 10 ] = 1.; arr[ 11 ] = 0.;
        arr[ 12 ] = 0.; arr[ 13 ] = 0.; arr[ 14 ] = 0.; arr[ 15 ] = 1.;
        gl = createWebGl( width, height );
        scale = 1/(width/2);
        triangles = new TriangleArray();
        // 'using' allows us to put gl in front of the function making the code more descriptive
        var vertex = gl.createShaderFromString( RenderingContext.VERTEX_SHADER, vertexString );
        var fragment = gl.createShaderFromString( RenderingContext.FRAGMENT_SHADER, fragmentString );
        program = gl.createShaderProgram( vertex, fragment );
        
        var path = new Fine( null, null, both );
        path.width = 2.5;
        var scaleContext = new ScaleContext( path, 1, 1 );
        var p = new SvgPath( scaleContext );
        p.parse( bird_d );
        var x0: Float = 0.;
        var y0: Float = 0.;
        for( i in 0...Std.int( height/15 ) ){
            scaleContext.moveTo( x0, y0 );
            scaleContext.lineTo( width, y0 );
            y0+=15;
        }
        triangles.addArray( 6
                        ,   path.trilateralArray
                        ,   appColors.indexOf( White ) );
        imageLoader = new ImageLoader( [], loaded );
        imageLoader.loadEncoded( [ HaxeLogo.gif ],[ 'haxelogo' ] );
    }
    function loaded(){
        setTriangleImage( triangles, cast( imageLoader.images.get('haxelogo'), Image ) );
        setAnimate();
    }
    inline
    function setAnimate(){
        AnimateTimer.create();
        AnimateTimer.onFrame = render_;
    } 
    // called every frame, sets transform and redraws
    function render_(i: Int ):Void{
        // we can multiply two rotations to get an interesting movement of the static 2D triangles.
        modelViewProjection = Matrix4x3.unit;
        modelViewProjection = Matrix4x3.radianZ( theta += Math.PI/200 ) * Matrix4x3.radianY( theta ); // Remove this line to stop 3D rotation
        render();
    }
    function createWebGl( width_: Int, height_: Int ): RenderingContext {
        canvas = Browser.document.createCanvasElement();
        canvas.width = width;
        canvas.height = height;
        var dom = cast canvas;
        var style = dom.style;
        style.paddingLeft = "0px";
        style.paddingTop = "0px";
        style.left = '0px';
        style.top = '0px';
        style.position = "absolute";
        Browser.document.body.appendChild( cast canvas );
        var gl = canvas.getContextWebGL( { 'antialias': true } );
        return gl;
    }
    static inline function createShaderProgram( gl: RenderingContext, vertex: Shader, fragment: Shader ): Program {
        var program = gl.createProgram();
        gl.attachShader( program, vertex );
        gl.attachShader( program, fragment );
        gl.linkProgram( program );
        gl.useProgram( program );
        return program;
    }
    // used for generating fragment and vertex shaders from strings
    static inline function createShaderFromString( gl: RenderingContext, shaderType: Int, shaderString: String ): Shader {
        var shader = gl.createShader( shaderType );
        gl.shaderSource( shader, shaderString ); 
        gl.compileShader( shader );
        return shader;
    }
    function setTriangleImage( triangles: Array<Triangle>, image: Image ) {
        var tri: Triangle;
        var count = 0;
        var ox: Float = -1.0;
        var oy: Float = 1.0;
        var oz: Float = 0.;
        var tx: Float = -0.5;
        var ty: Float = -0.5;
        for( i in 0...triangles.length ){
            tri = triangles[ i ];
            
            vertices.push( tri.ax*scale + ox );
            texturePos.push( tri.ax*scale + tx );
            vertices.push( -tri.ay*scale + oy );
            texturePos.push( tri.ay*scale + ty );
            vertices.push( tri.depth );
            vertices.push( tri.bx*scale + ox );
            texturePos.push( tri.bx*scale + tx );
            vertices.push( -tri.by*scale + oy );
            texturePos.push( tri.by*scale + ty );
            vertices.push( tri.depth );
            vertices.push( tri.cx*scale + ox );
            texturePos.push( tri.cx*scale + tx );
            vertices.push( -tri.cy*scale + oy );
            texturePos.push( tri.cy*scale + ty );
            vertices.push( tri.depth );
            for( k in 0...3 ) indices.push( count++ );
        } 
        gl.passAttributeToShader( program, 'pos', 3, vertices ); // position data
        gl.passIndicesToShader( indices ); // indices data 
        gl.uploadImage( program, image, texturePos ); // image data
    }
    static inline function uploadImage( gl: RenderingContext, program: Program, image: Image, texturePos: Array<Float> ){
        var texCoordLocation = gl.getAttribLocation(program, "aTexture");
        var texCoordBuffer = gl.createBuffer();
        gl.bindBuffer( RenderingContext.ARRAY_BUFFER, texCoordBuffer);
        gl.bufferData( RenderingContext.ARRAY_BUFFER, new Float32Array( texturePos ), RenderingContext.STATIC_DRAW );
        gl.enableVertexAttribArray( texCoordLocation);
        gl.vertexAttribPointer( texCoordLocation, 2, RenderingContext.FLOAT, false, 0, 0 );
        var texture = gl.createTexture();
        gl.activeTexture( RenderingContext.TEXTURE0 );
        gl.bindTexture( RenderingContext.TEXTURE_2D, texture );
        gl.pixelStorei( RenderingContext.UNPACK_FLIP_Y_WEBGL, 1 );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_S, RenderingContext.CLAMP_TO_EDGE );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_T, RenderingContext.CLAMP_TO_EDGE );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.NEAREST );
        gl.texParameteri( RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MAG_FILTER, RenderingContext.NEAREST );
        gl.texImage2D( RenderingContext.TEXTURE_2D, 0, RenderingContext.RGBA, RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, image );
    }
    static inline function passIndicesToShader( gl: RenderingContext, indices: Array<Int> ){
        var indexBuffer = gl.createBuffer(); // triangle indicies data 
        gl.bindBuffer( RenderingContext.ELEMENT_ARRAY_BUFFER, indexBuffer );
        gl.bufferData( RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16Array( indices ), RenderingContext.STATIC_DRAW );
        gl.bindBuffer( RenderingContext.ELEMENT_ARRAY_BUFFER, null );
    }
    // generic passing attributes to shader.
    static inline function passAttributeToShader( gl: RenderingContext, program: Program, name: String, att: Int, arr: Array<Float> ){
        var floatBuffer = gl.createBuffer();
        gl.bindBuffer( RenderingContext.ARRAY_BUFFER, floatBuffer );
        gl.bufferData( RenderingContext.ARRAY_BUFFER, new Float32Array( arr ), RenderingContext.STATIC_DRAW );
        var flo = gl.getAttribLocation( program, name );
        gl.vertexAttribPointer( flo, att, RenderingContext.FLOAT, false, 0, 0 ); 
        gl.enableVertexAttribArray( flo );
        gl.bindBuffer( RenderingContext.ARRAY_BUFFER, null );
    }
    function render(){
        // setup and clear
        gl.clearColor( 0.5, 0.0, 0.5, 0.9 );
        gl.enable( RenderingContext.DEPTH_TEST );
        gl.clear( RenderingContext.COLOR_BUFFER_BIT );
        gl.viewport( 0, 0, canvas.width, canvas.height );
        // apply transform matrices 
        var modelViewProjectionID = gl.getUniformLocation( program, 'modelViewProjection' );
        matrix32Array = modelViewProjection.updateWebGL_( matrix32Array );
        gl.uniformMatrix4fv( modelViewProjectionID, false, untyped matrix32Array );
        // draw
        gl.drawArrays( RenderingContext.TRIANGLES, 0, indices.length );
    }
    var quadtest_d = "M200,300 Q400,50 600,300 T1000,300";
    var cubictest_d = "M100,200 C100,100 250,100 250,200S400,300 400,200";
    var bird_d = "M210.333,65.331C104.367,66.105-12.349,150.637,1.056,276.449c4.303,40.393,18.533,63.704,52.171,79.03c36.307,16.544,57.022,54.556,50.406,112.954c-9.935,4.88-17.405,11.031-19.132,20.015c7.531-0.17,14.943-0.312,22.59,4.341c20.333,12.375,31.296,27.363,42.979,51.72c1.714,3.572,8.192,2.849,8.312-3.078c0.17-8.467-1.856-17.454-5.226-26.933c-2.955-8.313,3.059-7.985,6.917-6.106c6.399,3.115,16.334,9.43,30.39,13.098c5.392,1.407,5.995-3.877,5.224-6.991c-1.864-7.522-11.009-10.862-24.519-19.229c-4.82-2.984-0.927-9.736,5.168-8.351l20.234,2.415c3.359,0.763,4.555-6.114,0.882-7.875c-14.198-6.804-28.897-10.098-53.864-7.799c-11.617-29.265-29.811-61.617-15.674-81.681c12.639-17.938,31.216-20.74,39.147,43.489c-5.002,3.107-11.215,5.031-11.332,13.024c7.201-2.845,11.207-1.399,14.791,0c17.912,6.998,35.462,21.826,52.982,37.309c3.739,3.303,8.413-1.718,6.991-6.034c-2.138-6.494-8.053-10.659-14.791-20.016c-3.239-4.495,5.03-7.045,10.886-6.876c13.849,0.396,22.886,8.268,35.177,11.218c4.483,1.076,9.741-1.964,6.917-6.917c-3.472-6.085-13.015-9.124-19.18-13.413c-4.357-3.029-3.025-7.132,2.697-6.602c3.905,0.361,8.478,2.271,13.908,1.767c9.946-0.925,7.717-7.169-0.883-9.566c-19.036-5.304-39.891-6.311-61.665-5.225c-43.837-8.358-31.554-84.887,0-90.363c29.571-5.132,62.966-13.339,99.928-32.156c32.668-5.429,64.835-12.446,92.939-33.85c48.106-14.469,111.903,16.113,204.241,149.695c3.926,5.681,15.819,9.94,9.524-6.351c-15.893-41.125-68.176-93.328-92.13-132.085c-24.581-39.774-14.34-61.243-39.957-91.247c-21.326-24.978-47.502-25.803-77.339-17.365c-23.461,6.634-39.234-7.117-52.98-31.273C318.42,87.525,265.838,64.927,210.333,65.331zM445.731,203.01c6.12,0,11.112,4.919,11.112,11.038c0,6.119-4.994,11.111-11.112,11.111s-11.038-4.994-11.038-11.111C434.693,207.929,439.613,203.01,445.731,203.01z";
}