import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/pages/comic_page.dart';
import 'package:venera/pages/downloading_page.dart';
import 'package:venera/pages/favorites/favorites_page.dart';
import 'package:venera/utils/cbz.dart';
import 'package:venera/utils/epub.dart';
import 'package:venera/utils/io.dart';
import 'package:venera/utils/pdf.dart';
import 'package:venera/utils/translations.dart';

class LocalComicsPage extends StatefulWidget {
  const LocalComicsPage({super.key});

  @override
  State<LocalComicsPage> createState() => _LocalComicsPageState();
}

class _LocalComicsPageState extends State<LocalComicsPage> {
  late List<LocalComic> comics;

  late LocalSortType sortType;

  String keyword = "";

  bool searchMode = false;

  bool multiSelectMode = false;

  Map<LocalComic, bool> selectedComics = {};

  void update() {
    if (keyword.isEmpty) {
      setState(() {
        comics = LocalManager().getComics(sortType);
      });
    } else {
      setState(() {
        comics = LocalManager().search(keyword);
      });
    }
  }

  @override
  void initState() {
    var sort = appdata.implicitData["local_sort"] ?? "name";
    sortType = LocalSortType.fromString(sort);
    comics = LocalManager().getComics(sortType);
    LocalManager().addListener(update);
    super.initState();
  }

  @override
  void dispose() {
    LocalManager().removeListener(update);
    super.dispose();
  }

  void sort() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "Sort".tl,
            content: Column(
              children: [
                RadioListTile<LocalSortType>(
                  title: Text("Name".tl),
                  value: LocalSortType.name,
                  groupValue: sortType,
                  onChanged: (v) {
                    setState(() {
                      sortType = v!;
                    });
                  },
                ),
                RadioListTile<LocalSortType>(
                  title: Text("Date".tl),
                  value: LocalSortType.timeAsc,
                  groupValue: sortType,
                  onChanged: (v) {
                    setState(() {
                      sortType = v!;
                    });
                  },
                ),
                RadioListTile<LocalSortType>(
                  title: Text("Date Desc".tl),
                  value: LocalSortType.timeDesc,
                  groupValue: sortType,
                  onChanged: (v) {
                    setState(() {
                      sortType = v!;
                    });
                  },
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  appdata.implicitData["local_sort"] = sortType.value;
                  appdata.writeImplicitData();
                  Navigator.pop(context);
                  update();
                },
                child: Text("Confirm".tl),
              ),
            ],
          );
        });
      },
    );
  }

  Widget buildMultiSelectMenu() {
    return MenuButton(entries: [
      MenuEntry(
        icon: Icons.delete_outline,
        text: "Delete".tl,
        onClick: () {
          deleteComics(selectedComics.keys.toList()).then((value) {
            if (value) {
              setState(() {
                multiSelectMode = false;
                selectedComics.clear();
              });
            }
          });
        },
      ),
      MenuEntry(
        icon: Icons.favorite_border,
        text: "Add to favorites".tl,
        onClick: () {
          addFavorite(selectedComics.keys.toList());
        },
      ),
      if (selectedComics.length == 1)
        MenuEntry(
          icon: Icons.chrome_reader_mode_outlined,
          text: "View Detail".tl,
          onClick: () {
            context.to(() => ComicPage(
              id: selectedComics.keys.first.id,
              sourceKey: selectedComics.keys.first.sourceKey,
            ));
          },
        ),
      if (selectedComics.length == 1)
        ...exportActions(selectedComics.keys.first),
    ]);
  }

  void selectAll() {
    setState(() {
      selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
    });
  }

  void deSelect() {
    setState(() {
      selectedComics.clear();
    });
  }

  void invertSelection() {
    setState(() {
      comics.asMap().forEach((k, v) {
        selectedComics[v] = !selectedComics.putIfAbsent(v, () => false);
      });
      selectedComics.removeWhere((k, v) => !v);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> selectActions = [
      IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: "Select All".tl,
          onPressed: selectAll),
      IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: "Deselect".tl,
          onPressed: deSelect),
      IconButton(
          icon: const Icon(Icons.flip),
          tooltip: "Invert Selection".tl,
          onPressed: invertSelection),
      buildMultiSelectMenu(),
    ];

    List<Widget> normalActions = [
      Tooltip(
        message: "Search".tl,
        child: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              searchMode = true;
            });
          },
        ),
      ),
      Tooltip(
        message: "Sort".tl,
        child: IconButton(
          icon: const Icon(Icons.sort),
          onPressed: sort,
        ),
      ),
      Tooltip(
        message: "Downloading".tl,
        child: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {
            showPopUpWidget(context, const DownloadingPage());
          },
        ),
      ),
    ];

    var body = Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          if (!searchMode)
            SliverAppbar(
              leading: Tooltip(
                message: multiSelectMode ? "Cancel".tl : "Back".tl,
                child: IconButton(
                  onPressed: () {
                    if (multiSelectMode) {
                      setState(() {
                        multiSelectMode = false;
                        selectedComics.clear();
                      });
                    } else {
                      context.pop();
                    }
                  },
                  icon: multiSelectMode
                      ? const Icon(Icons.close)
                      : const Icon(Icons.arrow_back),
                ),
              ),
              title: multiSelectMode
                  ? Text(selectedComics.length.toString())
                  : Text("Local".tl),
              actions: multiSelectMode ? selectActions : normalActions,
            )
          else if (searchMode)
            SliverAppbar(
              leading: Tooltip(
                message: "Cancel".tl,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      searchMode = false;
                      keyword = "";
                      update();
                    });
                  },
                ),
              ),
              title: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search".tl,
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  keyword = v;
                  update();
                },
              ),
            ),
          SliverGridComics(
            comics: comics,
            selections: selectedComics,
            onLongPressed: (c) {
              setState(() {
                multiSelectMode = true;
                selectedComics[c as LocalComic] = true;
              });
            },
            onTap: (c) {
              if (multiSelectMode) {
                setState(() {
                  if (selectedComics.containsKey(c as LocalComic)) {
                    selectedComics.remove(c);
                  } else {
                    selectedComics[c] = true;
                  }
                  if (selectedComics.isEmpty) {
                    multiSelectMode = false;
                  }
                });
              } else {
                (c as LocalComic).read();
              }
            },
            menuBuilder: (c) {
              return [
                MenuEntry(
                  icon: Icons.delete,
                  text: "Delete".tl,
                  onClick: () {
                    deleteComics([c as LocalComic]).then((value) {
                      if (value && multiSelectMode) {
                        setState(() {
                          multiSelectMode = false;
                          selectedComics.clear();
                        });
                      }
                    });
                  },
                ),
                ...exportActions(c as LocalComic),
              ];
            },
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedComics.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            update();
          });
        }
      },
      child: body,
    );
  }

  Future<bool> deleteComics(List<LocalComic> comics) async {
    bool isDeleted = false;
    await showDialog(
      context: App.rootContext,
      builder: (context) {
        bool removeComicFile = true;
        return StatefulBuilder(builder: (context, state) {
          return ContentDialog(
            title: "Delete".tl,
            content: CheckboxListTile(
              title: Text("Also remove files on disk".tl),
              value: removeComicFile,
              onChanged: (v) {
                state(() {
                  removeComicFile = !removeComicFile;
                });
              },
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  context.pop();
                  for (var comic in comics) {
                    LocalManager().deleteComic(
                      comic,
                      removeComicFile,
                    );
                  }
                  isDeleted = true;
                },
                child: Text("Confirm".tl),
              ),
            ],
          );
        });
      },
    );
    return isDeleted;
  }

  List<MenuEntry> exportActions(LocalComic c) {
    return [
      MenuEntry(
          icon: Icons.outbox_outlined,
          text: "Export as cbz".tl,
          onClick: () async {
            var controller = showLoadingDialog(
              context,
              allowCancel: false,
            );
            try {
              var file = await CBZ.export(c);
              await saveFile(filename: file.name, file: file);
              await file.delete();
            } catch (e, s) {
              context.showMessage(message: e.toString());
              Log.error("CBZ Export", e, s);
            }
            controller.close();
          }),
      MenuEntry(
        icon: Icons.picture_as_pdf_outlined,
        text: "Export as pdf".tl,
        onClick: () async {
          var cache = FilePath.join(App.cachePath, 'temp.pdf');
          var controller = showLoadingDialog(
            context,
            allowCancel: false,
          );
          try {
            await createPdfFromComicIsolate(
              comic: c,
              savePath: cache,
            );
            await saveFile(
              file: File(cache),
              filename: "${c.title}.pdf",
            );
          } catch (e, s) {
            Log.error("PDF Export", e, s);
            context.showMessage(message: e.toString());
          } finally {
            controller.close();
            File(cache).deleteIgnoreError();
          }
        },
      ),
      MenuEntry(
        icon: Icons.import_contacts_outlined,
        text: "Export as epub".tl,
        onClick: () async {
          var controller = showLoadingDialog(
            context,
            allowCancel: false,
          );
          File? file;
          try {
            file = await createEpubWithLocalComic(
              c,
            );
            await saveFile(
              file: file,
              filename: "${c.title}.epub",
            );
          } catch (e, s) {
            Log.error("EPUB Export", e, s);
            context.showMessage(message: e.toString());
          } finally {
            controller.close();
            file?.deleteIgnoreError();
          }
        },
      )
    ];
  }
}
