import "dart:io";

import "package:camera/camera.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:permission_handler/permission_handler.dart";
import "package:photo_manager/photo_manager.dart";
import "package:photo_manager_image_provider/photo_manager_image_provider.dart";

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? controller;
  List<CameraDescription> _cameras = <CameraDescription>[];
  AssetPathEntity? _path;
  List<AssetEntity>? _entities;
  final FilterOptionGroup _filterOptionGroup = FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final PermissionStatus cameraPermissionStatus =
        await Permission.camera.status;
    if (cameraPermissionStatus.isDenied) {
      await Permission.camera.request();
    }

    final PermissionStatus storagePermissionStatus =
        await Permission.storage.status;
    if (storagePermissionStatus.isDenied) {
      await Permission.storage.request();
    }

    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameras = cameras;
      onNewCameraSelected(cameras.first);
    }
  }

  Future<void> _requestAssets() async {
    // Request permissions.
    // final PermissionState ps = await PhotoManager.requestPermissionExtend();
    final PermissionStatus status = await Permission.storage.status;
    if (status.isDenied) {
      await Permission.storage.request();
    }

    if (!mounted) {
      return;
    }

    // Further requests can be only proceed with authorized or limited.
    // if (!ps.hasAccess) {
    //   return;
    // }

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      filterOption: _filterOptionGroup,
    );
    _path = paths.first;

    final List<AssetEntity> entities = await _path!.getAssetListPaged(
      page: 0,
      size: 8,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _entities = entities;
    });
  }

  Future<void> _initializeCameraController(
    CameraDescription cameraDescription,
  ) async {
    final PermissionStatus status = await Permission.camera.status;
    if (status.isDenied) {
      await Permission.camera.request().isGranted;
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    await cameraController.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    try {
      await controller!.initialize();
      setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((XFile? file) {
      if (mounted) {
        Navigator.pop(context, file);
      }
    });
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      debugPrint("Error: select a camera first.");
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      return null;
    }

    try {
      final XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      debugPrint("takePicture errr: $e");
      return null;
    }
  }

  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(
        child: Text(
          "No avaiable",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else {
      // return CameraPreview(controller!);
      return CameraPreview(controller!);
    }
  }

  Widget _backButton() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 50.0,
        left: 20.0,
      ),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _actionRow() {
    void onChanged(CameraDescription? description) {
      if (description == null) {
        return;
      }

      onNewCameraSelected(description);
    }

    return Expanded(
      child: Container(
        color: Colors.grey[200],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (_cameras.length > 1)
                GestureDetector(
                  onTap: () {
                    final CameraDescription newDescription =
                        controller!.description == _cameras[0]
                            ? _cameras[1]
                            : _cameras[0];
                    onChanged(newDescription);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cameraswitch_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onTakePictureButtonPressed,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.black.withOpacity(0.2),
                      size: 45,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? imagexFile = await picker.pickImage(
                    source: ImageSource.gallery,
                  );

                  if (imagexFile != null) Navigator.pop(context, imagexFile);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galleryList() {
    return _entities == null || _entities!.isEmpty
        ? const SizedBox()
        : Container(
            width: double.infinity,
            height: 75,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _entities?.length,
              itemBuilder: (_, int index) => GestureDetector(
                onTap: () async {
                  final File? file = await _entities![index].file;
                  Navigator.pop(context, XFile(file!.path));
                },
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: AssetEntityImage(
                    _entities![index],
                    isOriginal: false,
                    fit: BoxFit.cover,
                    width: 75,
                    // height: 50,
                  ),
                ),
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              _cameraPreviewWidget(),
              _galleryList(),
              _backButton(),
            ],
          ),
          _actionRow(),
        ],
      ),
    );
  }
}
