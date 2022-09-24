/++
$(H2 CSV/TSV parsing)

DRAFT

$(LREF Csv) can be serialized to Ion, JSON, MsgPack, or YAML
and then deserialized to a specified type.
That approachs allows to use the same mir deserialization
pattern like for other data types.
$(IONREF conv, serde) unifies this two steps throught binary Ion format,
which serves as an efficient DOM representation for all other formats.

We provide seven variants of how $(LREF CsvKind) can be represented
in Ion notation.

Macros:
    IONREF = $(REF_ALTTEXT $(TT $2), $2, mir, ion, $1)$(NBSP)
    AlgorithmREF = $(GREF_ALTTEXT mir-algorithm, $(TT $2), $2, mir, $1)$(NBSP)
    AAREF = $(REF_ALTTEXT $(TT $2), $2, mir, algebraic_alias, $1)$(NBSP)
+/
module mir.csv;

///
unittest
{
    import mir.csv;
    import mir.ion.conv: serde; // to convert Csv to D types
    import mir.serde: serdeKeys, serdeIgnoreUnexpectedKeys, serdeOptional;
    // mir.date and std.datetime are supported as well
    import mir.timestamp: Timestamp;//mir-algorithm package
    import mir.test: should;

    auto text =
`Date,Open,High,Low,Close,Volume
2021-01-21 09:30:00,133.8,134.43,133.59,134.0,9166695
2021-01-21 09:35:00,134.25,135.0,134.19,134.5,4632863`;

    Csv csv = {
        text: text,
        // We allow 7 CSV payloads!
        kind: CsvKind.dataFrame
    };

    // If you don't have a header,
    // `mir.functional.Tuple` instead of MyDataFrame.
    @serdeIgnoreUnexpectedKeys //ignore all other columns
    static struct MyDataFrame
    {
        // Few keys are allowed
        @serdeKeys(`Date`, `date`, `timestamp`)
        Timestamp[] timestamp;

        @serdeKeys(`Open`)  double[]    open;
        @serdeKeys(`High`)  double[]    high;
        @serdeKeys(`Low`)   double[]    low;
        @serdeKeys(`Close`) double[]    close;

        @serdeOptional // if we don't have Volume
        @serdeKeys(`Volume`)
        long[]volume;
    }

    MyDataFrame testValue = {
        timestamp:  [`2021-01-21 09:30:00`.Timestamp, `2021-01-21 09:35:00`.Timestamp],
        volume:     [9166695, 4632863],
        open:       [133.8,  134.25],
        high:       [134.43, 135],
        low:        [133.59, 134.19],
        close:      [134.0,  134.5],
    };

    csv.serde!MyDataFrame.should == testValue;

    ///////////////////////////////////////////////
    /// More flexible Data Frame

    import mir.algebraic_alias.csv: CsvAlgebraic;
    alias DataFrame = CsvAlgebraic[][string];
    auto flex = csv.serde!DataFrame;

    flex["Volume"][1].should == 4632863;
}

///
public import mir.algebraic_alias.csv: CsvAlgebraic;

/++
CSV representation kind.
+/
enum CsvKind
{
    /++
    Array of rows.

    Ion_Payload:
    ```
    [
        [cell_0_0, cell_0_1, cell_0_2, ...],
        [cell_1_0, cell_1_1, cell_1_2, ...],
        [cell_2_0, cell_2_1, cell_2_2, ...],
        ...
    ]
    ```
    +/
    matrix,
    /++
    Arrays of objects with object field names from the header.

    Ion_Payload:
    ```
    [
        {
            cell_0_0: cell_1_0,
            cell_0_1: cell_1_1,
            cell_0_2: cell_1_2,
            ...
        },
        {
            cell_0_0: cell_2_0,
            cell_0_1: cell_2_1,
            cell_0_2: cell_2_2,
            ...
        },
        ...
    ]
    ```
    +/
    objects,
    /++
    Indexed array of rows with index from the first column.

    Ion_Payload:
    ```
    {
        data: [
            [cell_0_1, cell_0_2, ...],
            [cell_1_1, cell_1_2, ...],
            [cell_2_1, cell_2_2, ...],
            ...
        ],
        index: [cell_0_0, cell_1_0, cell_2_0, ...]
    }
    ```
    +/
    series,
    /++
    DataFrame representation.

    Ion_Payload:
    ```
    {
        indexName: cell_0_0,
        columnNames: [cell_0_1, cell_0_2, ...],
        data: [
            [cell_1_1, cell_1_2, ...],
            [cell_2_1, cell_2_2, ...],
            ...
        ],
        index: [cell_1_0, cell_2_0, ...]
    }
    ```
    +/
    seriesWithHeader,
    /++
    Indexed arrays of objects with index from the first column and object field names from the header.

    Ion_Payload:
    ```
    {
        data: [
            {
                cell_0_1: cell_1_1,
                cell_0_2: cell_1_2,
                ...
            },
            {
                cell_0_1: cell_2_1,
                cell_0_2: cell_2_2,
                ...
            },
            ...
        ],
        index: [cell_1_0, cell_2_0, ...]
    }
    ```
    +/
    seriesOfObjects,
    /++
    Array of columns.

    Ion_Payload:
    ```
    [
        [cell_0_0, cell_1_0, cell_2_0, ...],
        [cell_0_1, cell_1_1, cell_2_1, ...],
        [cell_0_2, cell_1_2, cell_2_2, ...],
        ...
    ]
    ```
    +/
    transposedMatrix,
    /++
    Object of columns with object field names from the header.

    Ion_Payload:
    ```
    {
        cell_0_0: [cell_1_0, cell_2_0, ...],
        cell_0_1: [cell_1_1, cell_2_1, ...],
        cell_0_2: [cell_1_2, cell_2_2, ...],
        ...
    }
    ```
    +/
    dataFrame,
}

/++
+/
struct Csv
{
    private static immutable NA_default = [
        ``,
        `#N/A`,
        `#N/A N/A`,
        `#NA`,
        `<NA>`,
        `N/A`,
        `NA`,
        `n/a`,
    ];
        // "NULL",
        // "null",

        // "1.#IND",
        // "-1.#QNAN",
        // "-1.#IND",
        // "1.#QNAN",

        // "-NaN",
        // "-nan",
        // "nan",
        // "NaN",

    ///
    const(char)[] text;
    ///
    CsvKind kind;
    ///
    char separator = ',';
    ///
    bool stripUnquoted = false; 
    ///
    char comment = char.init;
    ///
    ubyte rowsToSkip;
    /++
    NA patterns are converted to Ion `null` when exposed to arrays
    and skipped when exposed to objects
    +/
    const(string)[] naStrings = NA_default;
    /// File name for berrer error messages
    string fileName = "<unknown>";

    // /++
    // +/
    // bool delegate(size_t columnIndex, scope const(char)[] columnName) useColumn;

    /++
    Conversion callback to finish conversion resolution
    Params:
        unquotedString = string after unquoting
        isQuoted = is the original data field is quoted
        columnIndex = column index starting from 0
        columnName = column name if any
    +/
    CsvAlgebraic delegate(
        return scope const(char)[] unquotedString,
        return scope CsvAlgebraic scalar,
        size_t columnIndex,
        scope const(char)[] columnName
    ) @safe pure @nogc conversionFinalizer;

    /++
    +/
    static bool defaultIsSymbolHandler(scope const(char)[] symbol, bool quoted) @safe pure @nogc nothrow
    {
        import mir.deser.text.tokens: symbolNeedsQuotes;
        return !quoted && symbol.length && !symbolNeedsQuotes(symbol) && symbol[0] != '$';
    }

    /++
    A function used to determine if a string should be passed
    to a serializer as a symbol instead of strings.
    That may help to reduce memory allocation for data with
    a huge amount of equal cell values.``
    The default pattern follows regular expression `[a-zA-Z_][a-zA-Z_0-9]*`
    and requires symbol to be presented without double quotes.
    +/
    bool function(scope const(char)[] symbol, bool quoted) @safe pure @nogc isSymbolHandler = &defaultIsSymbolHandler;

    void serialize(S)(scope ref S serializer) scope const @trusted
    {
        // DRAFT
        // TODO: have to be @nogc
        // import std.ascii;
        import mir.appender: scopedBuffer;
        import mir.bignum.decimal: Decimal, DecimalExponentKey;
        import mir.exception: MirException;
        import mir.ndslice.dynamic: transposed;
        import mir.ndslice.slice: sliced;
        import mir.parse: ParsePosition;
        import mir.ser: serializeValue;
        import mir.timestamp: Timestamp;
        import mir.utility: _expect;
        import std.algorithm.iteration: splitter;
        import std.algorithm.searching: canFind;
        import std.string: lineSplitter, strip;

        auto headerBuff = scopedBuffer!(const(char)[]);
        auto unquotedStringStringBuff = scopedBuffer!(const(char));
        auto indexBuff = scopedBuffer!CsvAlgebraic;
        auto dataBuff = scopedBuffer!CsvAlgebraic;
        scope const(char)[][] header;
        auto nColumns = size_t.max;

        Decimal!128 decimal = void;
        DecimalExponentKey decimalKey;

        Timestamp timestamp;

        const transp =
            kind == CsvKind.transposedMatrix || 
            kind == CsvKind.dataFrame;

        const hasInternalHeader =
            kind == CsvKind.objects ||
            kind == CsvKind.seriesOfObjects;

        const hasHeader = hasInternalHeader ||
            kind == CsvKind.dataFrame ||
            kind == CsvKind.seriesWithHeader;

        const hasIndex =
            kind == CsvKind.series ||
            kind == CsvKind.seriesOfObjects ||
            kind == CsvKind.seriesWithHeader;
        
        bool initLoop;

        size_t wrapperState;
        size_t outerState;

        size_t i;
        foreach (line; text.lineSplitter)
        {
            i++;
            if (i <= rowsToSkip)
                continue;
            if (line.length == 0)
            {
                // TODO
            }
            if (line[0] == comment)
                continue;
            size_t j;
            if (header is null && hasHeader)
            {
                foreach (value; line.splitter(separator))
                {
                    j++;
                    if (stripUnquoted)
                        value = value.strip;
                    if (value.canFind('"'))
                    {
                        // TODO unqote
                        value = value.strip;
                    }
                    () @trusted {
                        headerBuff.put(value);
                    } ();
                }
                header = headerBuff.data;
                assert(header.length);
                assert(j == header.length);
                nColumns = j;
                continue;
            }
            if (!initLoop)
            {
                initLoop = true;
                if (!transp)
                {
                    if (hasIndex)
                    {
                        wrapperState = serializer.structBegin(kind == CsvKind.seriesWithHeader ? 4 : 2);
                        if (kind == CsvKind.seriesWithHeader)
                        {
                            serializer.putKey("indexName");
                            serializer.putSymbol(header[0]);
                            serializer.putKey("columnNames");
                            auto state = serializer.listBegin(header.length - 1);
                            foreach (name; header[1 .. $])
                            {
                                serializer.elemBegin;
                                serializer.putSymbol(name);
                            }
                            serializer.listEnd(state);
                        }
                        serializer.putKey("data");
                    }
                    outerState = serializer.listBegin;
                }
            }
            size_t state;
            if (!transp)
            {
                serializer.elemBegin;
                if (hasInternalHeader)
                    state = serializer.structBegin(nColumns);
                else
                    state = serializer.listBegin(nColumns);
            }
            foreach (value; splitter(line, separator))
            {
                // The same like Mir deserializatin from string to floating
                enum bool allowSpecialValues = true;
                enum bool allowDotOnBounds = true;
                enum bool allowDExponent = true;
                enum bool allowStartingPlus = true;
                enum bool allowUnderscores = false;
                enum bool allowLeadingZeros = true;
                enum bool allowExponent = true;
                enum bool checkEmpty = false;

                j++;
                if (j > nColumns)
                    break;

                if (stripUnquoted)
                    value = value.strip;

                CsvAlgebraic scalar;

                bool quoted;

                if (value.canFind('"'))
                {
                    quoted = true;
                    // TODO unqote
                    value = value.strip;
                }
                else
                if (value.length && decimal.fromStringImpl!(
                    char,
                    allowSpecialValues,
                    allowDotOnBounds,
                    allowDExponent,
                    allowStartingPlus,
                    allowUnderscores,
                    allowLeadingZeros,
                    allowExponent,
                    checkEmpty,
                )(value, decimalKey))
                {
                    if (decimalKey)
                        scalar = cast(double) decimal;
                    else
                        scalar = cast(long) decimal.coefficient;
                }
                else
                if (Timestamp.fromString(value, timestamp))
                {
                    scalar = timestamp;
                }
                else
                S: switch (value)
                {
                    case "true":
                    case "True":
                    case "TRUE":
                        scalar = true;
                        break;
                    case "false":
                    case "False":
                    case "FALSE":
                        scalar = false;
                        break;
                    default:
                        foreach (na; naStrings)
                            if (na == value)
                                break S; // null
                        () @trusted {
                            scalar = cast(string) value;
                            bool quoted = false;
                        } ();
                }

                if (_expect(conversionFinalizer !is null, false))
                {
                    scalar.isQuoted = quoted;
                    scalar = conversionFinalizer(value, scalar, j - 1, hasHeader ? header[j - 1] : null);
                }

                if (j == 1 && hasIndex)
                {
                    indexBuff.put(scalar);
                }
                else
                if (!transp)
                {
                    if (!hasInternalHeader)
                        serializer.elemBegin();
                    else
                    if (scalar.isNull)
                        goto Skip;
                    else
                        serializer.putKey(header[j - 1]);

                    if (scalar._is!string && isSymbolHandler(scalar.trustedGet!string, scalar.isQuoted))
                        serializer.putSymbol(scalar.trustedGet!string);
                    else
                        serializer.serializeValue(scalar);
                Skip:
                }
                else
                {
                    dataBuff.put(scalar);
                }
            }
            if (j != nColumns && nColumns != nColumns.max)
            {
                throw new MirException("CSV: Expected ", nColumns, ", got ", j, " at:\n", ParsePosition(fileName, cast(uint)i, 0));
            }
            nColumns = j;

            if (!transp)
            {
                if (hasInternalHeader)
                    serializer.structEnd(state);
                else
                    serializer.listEnd(state);
            }
        }
        if (!transp)
        {
            if (!initLoop)
                outerState = serializer.listBegin(0);
            serializer.listEnd(outerState);

            if (hasIndex)
            {
                serializer.putKey("index");
                serializer.serializeValue(indexBuff.data);
                serializer.structEnd(wrapperState);
            }
        }

        if (transp)
        {
            // auto data = dataBuff.data.sliced(nColumns ? dataBuff.data.length / nColumns : 0, nColumns);
            // auto transposedData = data.transposed;
            auto data = dataBuff.data;

            auto nRows = nColumns ? data.length / nColumns : 0;
            assert(nRows * nColumns == data.length);

            auto state = hasHeader ? serializer.structBegin(nColumns) : serializer.listBegin(nColumns);
            foreach (j; 0 .. nColumns)
            {
                hasHeader ? serializer.putKey(header[j]) : serializer.elemBegin;
                auto listState = serializer.listBegin(nRows);
                foreach (ii; 0 .. nRows)
                {
                    serializer.elemBegin;

                    auto scalar = data[ii * nColumns + j];
                    if (scalar._is!string && isSymbolHandler(scalar.trustedGet!string, scalar.isQuoted))
                        serializer.putSymbol(scalar.trustedGet!string);
                    else
                        serializer.serializeValue(scalar);
                }
                serializer.listEnd(listState);
            }
            hasHeader ? serializer.structEnd(state) : serializer.listEnd(state);
        }
    }
}

/++
Type resolution is performed for types defined in $(MREF mir,algebraic_alias,csv):

$(UL 
    $(LI `typeof(null)` - used for N/A values)
    $(LI `bool`)
    $(LI `long`)
    $(LI `double`)
    $(LI `string`)
    $(LI $(AlgorithmREF timestamp, Timestamp))
)
+/
unittest
{
    import mir.ion.conv: serde;
    import mir.ndslice.slice: Slice;
    import mir.ser.text: serializeTextPretty;
    import mir.test: should;
    import std.string: join;

    // alias Matrix = Slice!(CsvAlgebraic*, 2);

    Csv csv = {
        conversionFinalizer : (
            unquotedString,
            scalar,
            columnIndex,
            columnName)
        {
            // Do we want to symbolize the data?
            return !scalar.isQuoted && unquotedString == `Billion` ?
                1000000000.CsvAlgebraic :
                scalar;
        },
        text : join([
            // User-defined conversion
            `Billion`
            // `long` patterns
            , `100`, `+200`, `-200`
            // `double` pattern
            , `+1.0`, `-.2`, `3.`, `3e-10`, `3d20`,
            // also `double` pattern
            `inf`, `+Inf`, `-INF`, `+NaN`, `-nan`, `NAN`
            // `bool` patterns
            , `True`, `TRUE`, `true`, `False`, `FALSE`, `false`
            // `Timestamp` patterns
            , `2021-02-03` // iso8601 extended
            , `20210204T` // iso8601
            , `20210203T0506` // iso8601
            , `2001-12-15T02:59:43.1Z` //canonical
            , `2001-12-14t21:59:43.1-05:30` //with lower `t`
            , `2001-12-14 21:59:43.1 -5` //yaml space separated
            , `2001-12-15 2:59:43.10` //no time zone (Z):
            , `2002-12-14` //date (00:00:00Z):
            // Default NA patterns are converted to Ion `null` when exposed to arrays
            // and skipped when exposed to objects
            , ``
            , `#N/A`
            , `#N/A N/A`
            , `#NA`
            , `<NA>`
            , `N/A`
            , `NA`
            , `n/a`
            // strings patterns (TODO)
            , `100_000`
            , `_100`     // match default pattern for symbols
            , `Str`      // match default pattern for symbols
            , `Value100` // match default pattern for symbols
            , `iNF`      // match default pattern for symbols
            , `Infinity` // match default pattern for symbols
            , `+Infinity`
            , `.Infinity`
            // , `""`
            // , ` `
        ], `,`)
    };

    // Serializing Csv to Amazon Ion (text version)
    csv.serializeTextPretty!"    ".should ==
`[
    [
        1000000000,
        100,
        200,
        -200,
        1.0,
        -0.2,
        3.0,
        3e-10,
        3e+20,
        +inf,
        +inf,
        -inf,
        nan,
        nan,
        nan,
        true,
        true,
        true,
        false,
        false,
        false,
        2021-02-03,
        2021-02-04,
        2021-02-03T05:06Z,
        2001-12-15T02:59:43.1Z,
        2001-12-14T21:59:43.1-05:30,
        2001-12-14T21:59:43.1-05,
        2001-12-15T02:59:43.10Z,
        2002-12-14,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        "100_000",
        _100,
        Str,
        Value100,
        iNF,
        Infinity,
        "+Infinity",
        ".Infinity"
    ]
]`;
}

///
unittest
{
    import mir.csv;
    import mir.date: Date; // Phobos std.datetime supported as well
    import mir.ion.conv: serde; // to convert Csv to DataFrame
    import mir.ndslice.slice: Slice;//ditto
    import mir.timestamp: Timestamp;//mir-algorithm package
    // for testing
    import mir.ndslice.fuse: fuse;
    import mir.ser.text: serializeTextPretty;
    import mir.test: should;

    auto text =
`Date,Open,High,Low,Close,Volume
2021-01-21 09:30:00,133.8,134.43,133.59,134.0,9166695
2021-01-21 09:35:00,134.25,135.0,134.19,134.5,4632863`;

    Csv csv = {
        text: text,
        // We allow 7 CSV payloads!
        kind: CsvKind.seriesWithHeader
    };

    // Can be of any scalar type including `CsvAlgebraic`
    alias Elem = double;
    // `Elem[][]` matrix are supported as well.
    // But we like `Slice` because we can easily access columns
    alias Matrix = Slice!(Elem*, 2);

    static struct MySeriesWithHeader
    {
        string indexName;
        string[] columnNames;
        Matrix data;
        // Can be an array of any type that can be deserialized
        // like a string or `CsvAlgebraic`, `Date`, `DateTime`, or whatever.
        Timestamp[] index;
    }

    MySeriesWithHeader testSeries = {
        indexName: `Date`,
        columnNames: [`Open`, `High`, `Low`, `Close`, `Volume`],
        data: [
            [133.8, 134.43, 133.59, 134.0, 9166695],
            [134.25, 135.0, 134.19, 134.5, 4632863],
        ].fuse,
        index: [
            `2021-01-21T09:30:00Z`.Timestamp,
            `2021-01-21T09:35:00Z`.Timestamp,
        ],
    };

    // Check how Ion payload looks like
    csv.serializeTextPretty!"    ".should == q{{
    indexName: Date,
    columnNames: [
        Open,
        High,
        Low,
        Close,
        Volume
    ],
    data: [
        [
            133.8,
            134.43,
            133.59,
            134.0,
            9166695
        ],
        [
            134.25,
            135.0,
            134.19,
            134.5,
            4632863
        ]
    ],
    index: [
        2021-01-21T09:30:00Z,
        2021-01-21T09:35:00Z
    ]
}};
}

/++
How $(LREF CsvKind) are represented.
+/
unittest
{
    auto text = 
`Date,Open,High,Low,Close,Volume
2021-01-21 09:30:00,133.8,134.43,133.59,134.0,9166695
2021-01-21 09:35:00,134.25,135.0,134.19,134.5,4632863`;
        
}

/// Matrix & Transposed Matrix
unittest
{
    import mir.test: should;
    import mir.ndslice.slice: Slice;
    import mir.ion.conv: serde;

    alias Matrix = Slice!(double*, 2);

    auto text = "1,2\n3,4\r\n5,6\n";
    auto matrix = text.Csv.serde!Matrix;
    matrix.should == [[1, 2], [3, 4], [5, 6]];

    Csv csv = {
        text : text,
        kind : CsvKind.transposedMatrix
    };
    csv.serde!Matrix.should == [[1.0, 3, 5], [2.0, 4, 6]];
}

/++
Transposed Matrix & Tuple support
+/
unittest
{
    import mir.ion.conv: serde;
    import mir.date: Date; //also wotks with mir.timestamp and std.datetime
    import mir.functional: Tuple;
    import mir.ser.text: serializeText;
    import mir.test: should;

    Csv csv = {
        text : "str,2022-10-12,3.4\nb,2022-10-13,2\n",
        kind : CsvKind.transposedMatrix
    };

    csv.serializeText.should == `[[str,b],[2022-10-12,2022-10-13],[3.4,2]]`;

    alias T = Tuple!(string[], Date[], double[]);

    csv.serde!T.should == T (
        [`str`, `b`],
        [Date(2022, 10, 12), Date(2022, 10, 13)],
        [3.4, 2],
    );
}

/// Converting NA to NaN
unittest
{
    import mir.csv;
    import mir.algebraic: Nullable, visit;
    import mir.ion.conv: serde;
    import mir.ndslice: Slice, map, slice;
    import mir.ser.text: serializeText;
    import mir.test: should;

    auto text = "1,2\n3,4\n5,#N/A\n";
    auto matrix = text
        .Csv
        .serde!(Slice!(Nullable!double*, 2))
        .map!(visit!((double x) => x, (_) => double.nan))
        .slice;

    matrix.serializeText.should == q{[[1.0,2.0],[3.0,4.0],[5.0,nan]]};
}