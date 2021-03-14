import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:public_tools/core/PluginListItem.dart';

class PluginListItemView extends StatelessWidget {
  final PluginListItem item;

  final Function onTap;

  PluginListItemView({this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 54,
        child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.only(left: 10, right: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  item.icon != null
                      ? CachedNetworkImage(
                          imageUrl: item.icon,
                          placeholder: (context, string) => CircularProgressIndicator(),
                          width: 30,
                          height: 30,
                        )
                      : Icon(
                          Icons.account_circle_rounded,
                          size: 30,
                        ),
                  Expanded(
                    child: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  )),
                            ),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black38),
                            )
                          ],
                        )),
                  ),
                ],
              ),
            )));
  }
}