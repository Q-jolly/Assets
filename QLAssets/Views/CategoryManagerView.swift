import SwiftUI


struct CategoryManagerView:
    View {

    private enum CategoryKind:
        String,
        CaseIterable,
        Identifiable {

        case expense =
            "支出"

        case income =
            "收入"


        var id:
            String {

            rawValue
        }
    }


    @AppStorage(
        CategoryStore
            .expenseKey
    )
    private var expenseStored =
        ""

    @AppStorage(
        CategoryStore
            .incomeKey
    )
    private var incomeStored =
        ""

    @State
    private var selectedKind:
        CategoryKind =
            .expense

    @State
    private var showAddCategory =
        false

    @State
    private var editingCategory:
        CategoryItem?

    @State
    private var showResetConfirmation =
        false


    private var currentItems:
        [CategoryItem] {

        switch selectedKind {

        case .expense:

            return CategoryStore
                .expenseCategories(
                    from:
                        expenseStored
                )

        case .income:

            return CategoryStore
                .incomeCategories(
                    from:
                        incomeStored
                )
        }
    }


    var body:
        some View {

        List {

            Section {

                Picker(
                    "类型",
                    selection:
                        $selectedKind
                ) {

                    ForEach(
                        CategoryKind
                            .allCases
                    ) { kind in

                        Text(
                            kind.rawValue
                        )
                        .tag(
                            kind
                        )
                    }
                }
                .pickerStyle(
                    .segmented
                )
            }


            Section {

                ForEach(
                    currentItems
                ) { item in

                    Button {

                        editingCategory =
                            item

                    } label: {

                        HStack(
                            spacing: 12
                        ) {

                            Image(
                                systemName:
                                    item.icon
                            )
                            .frame(
                                width: 30,
                                height: 30
                            )
                            .background(
                                Color(
                                    .secondarySystemBackground
                                )
                            )
                            .clipShape(
                                Circle()
                            )


                            Text(
                                item.name
                            )
                            .foregroundStyle(
                                .primary
                            )


                            Spacer()


                            Image(
                                systemName:
                                    "chevron.right"
                            )
                            .font(
                                .caption.bold()
                            )
                            .foregroundStyle(
                                .tertiary
                            )
                        }
                        .frame(
                            maxWidth:
                                .infinity,
                            alignment:
                                .leading
                        )
                        .contentShape(
                            Rectangle()
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                    .contentShape(
                        Rectangle()
                    )
                    .accessibilityLabel(
                        "编辑分类 \(item.name)"
                    )
                }
                .onDelete(
                    perform:
                        deleteItems
                )
                .onMove(
                    perform:
                        moveItems
                )

            } header: {

                HStack {

                    Text(
                        "\(selectedKind.rawValue)分类"
                    )

                    Spacer()

                    Text(
                        "\(currentItems.count) 个"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

            } footer: {

                Text(
                    "删除或重命名分类不会修改历史账单中的文字；以后记账将使用新的分类列表。"
                )
            }


            Section {

                Button {

                    showAddCategory =
                        true

                } label: {

                    Label(
                        "添加分类",
                        systemImage:
                            "plus.circle.fill"
                    )
                }


                Button(
                    "恢复默认分类"
                ) {

                    showResetConfirmation =
                        true
                }
            }
        }
        .navigationTitle(
            "分类管理"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {

            EditButton()
        }
        .sheet(
            isPresented:
                $showAddCategory
        ) {

            CategoryEditorView(
                title:
                    "添加分类",
                existingNames:
                    currentItems.map(
                        \.name
                    )
            ) { item in

                var items =
                    currentItems

                items.append(
                    item
                )

                save(
                    items
                )
            }
        }
        .sheet(
            item:
                $editingCategory
        ) { item in

            CategoryEditorView(
                title:
                    "编辑分类",
                initialItem:
                    item,
                existingNames:
                    currentItems
                        .filter {
                            $0.id !=
                                item.id
                        }
                        .map(
                            \.name
                        )
            ) { updated in

                var items =
                    currentItems


                guard
                    let index =
                        items.firstIndex(
                            where: {
                                $0.id ==
                                    item.id
                            }
                        )
                else {

                    return
                }


                items[
                    index
                ] =
                    updated

                save(
                    items
                )
            }
        }
        .confirmationDialog(
            "恢复默认分类？",
            isPresented:
                $showResetConfirmation,
            titleVisibility:
                .visible
        ) {

            Button(
                "恢复默认",
                role:
                    .destructive
            ) {

                switch selectedKind {

                case .expense:

                    expenseStored =
                        CategoryStore
                            .encode(
                                CategoryStore
                                    .defaultExpense
                            )

                case .income:

                    incomeStored =
                        CategoryStore
                            .encode(
                                CategoryStore
                                    .defaultIncome
                            )
                }
            }


            Button(
                "取消",
                role:
                    .cancel
            ) {}

        } message: {

            Text(
                "当前自定义的分类顺序、名称和图标会被替换。"
            )
        }
    }


    private func save(
        _ items:
            [CategoryItem]
    ) {

        guard !items.isEmpty
        else {

            return
        }


        let encoded =
            CategoryStore
                .encode(
                    items
                )


        switch selectedKind {

        case .expense:

            expenseStored =
                encoded

        case .income:

            incomeStored =
                encoded
        }
    }


    private func deleteItems(
        at offsets:
            IndexSet
    ) {

        var items =
            currentItems

        items.remove(
            atOffsets:
                offsets
        )


        guard !items.isEmpty
        else {

            return
        }


        save(
            items
        )
    }


    private func moveItems(
        from source:
            IndexSet,
        to destination:
            Int
    ) {

        var items =
            currentItems

        items.move(
            fromOffsets:
                source,
            toOffset:
                destination
        )

        save(
            items
        )
    }
}


// MARK: - 分类编辑

private struct CategoryEditorView:
    View {

    let title:
        String

    var initialItem:
        CategoryItem?

    let existingNames:
        [String]

    let onSave:
        (CategoryItem) -> Void


    @Environment(
        \.dismiss
    )
    private var dismiss

    @State
    private var name:
        String

    @State
    private var icon:
        String

    @FocusState
    private var nameFocused:
        Bool


    init(
        title:
            String,
        initialItem:
            CategoryItem? = nil,
        existingNames:
            [String],
        onSave:
            @escaping (
                CategoryItem
            ) -> Void
    ) {

        self.title =
            title

        self.initialItem =
            initialItem

        self.existingNames =
            existingNames

        self.onSave =
            onSave

        _name =
            State(
                initialValue:
                    initialItem?
                        .name
                    ?? ""
            )

        _icon =
            State(
                initialValue:
                    initialItem?
                        .icon
                    ?? "tag.fill"
            )
    }


    private var normalizedName:
        String {

        name
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }


    private var canSave:
        Bool {

        !normalizedName
            .isEmpty &&
        !existingNames
            .contains(
                where: {
                    $0
                        .localizedCaseInsensitiveCompare(
                            normalizedName
                        ) ==
                        .orderedSame
                }
            )
    }


    var body:
        some View {

        NavigationStack {

            Form {

                Section(
                    "名称"
                ) {

                    TextField(
                        "例如：咖啡",
                        text:
                            $name
                    )
                    .focused(
                        $nameFocused
                    )
                    .submitLabel(
                        .done
                    )
                }


                Section(
                    "图标"
                ) {

                    LazyVGrid(
                        columns:
                            Array(
                                repeating:
                                    GridItem(
                                        .flexible()
                                    ),
                                count:
                                    5
                            ),
                        spacing:
                            14
                    ) {

                        ForEach(
                            CategoryStore
                                .availableIcons,
                            id:
                                \.self
                        ) { item in

                            Button {

                                icon =
                                    item

                            } label: {

                                Image(
                                    systemName:
                                        item
                                )
                                .font(
                                    .title3
                                )
                                .frame(
                                    width: 44,
                                    height: 44
                                )
                                .background(
                                    icon ==
                                        item
                                    ? Color
                                        .accentColor
                                        .opacity(
                                            0.16
                                        )
                                    : Color(
                                        .secondarySystemBackground
                                    )
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius:
                                            12,
                                        style:
                                            .continuous
                                    )
                                )
                                .overlay {

                                    if icon ==
                                        item {

                                        RoundedRectangle(
                                            cornerRadius:
                                                12,
                                            style:
                                                .continuous
                                        )
                                        .stroke(
                                            Color
                                                .accentColor,
                                            lineWidth:
                                                1.5
                                        )
                                    }
                                }
                            }
                            .buttonStyle(
                                .plain
                            )
                        }
                    }
                    .padding(
                        .vertical,
                        6
                    )
                }
            }
            .navigationTitle(
                title
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(
                        "取消"
                    ) {

                        dismiss()
                    }
                }


                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button(
                        "保存"
                    ) {

                        let item =
                            CategoryItem(
                                id:
                                    initialItem?
                                        .id
                                    ?? UUID(),
                                name:
                                    normalizedName,
                                icon:
                                    icon
                            )

                        onSave(
                            item
                        )

                        dismiss()
                    }
                    .disabled(
                        !canSave
                    )
                }


                ToolbarItemGroup(
                    placement:
                        .keyboard
                ) {

                    Spacer()

                    Button(
                        "完成"
                    ) {

                        nameFocused =
                            false
                    }
                }
            }
            .onAppear {

                nameFocused =
                    true
            }
        }
    }
}
